param(
	[Parameter(Mandatory = $true)]
	[string]$folder, 
	
	[Parameter(Mandatory = $false)]
	[bool]$doNotAsk, 
	
	[Parameter(Mandatory = $false)]
	[bool]$justKB,
	
	[Parameter(Mandatory = $false)]
	[bool]$print
)



function Get-Tomcat(){
	if (-not $script:tomcat){
		$script:tomcat = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\8.5\Tomcat8' -Name InstallPath
	}
}

function Get-SqlCmd(){
	if (-not $script:sqlcmd){
		$sqlVersions = @(140,130,120,110,100)
		foreach($v in $sqlVersions) {
			$hkey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($v)\Tools\ClientSetup"
			if (Test-Path $hkey){
				$script:sqlcmd = Get-ItemPropertyValue -Path $hkey -Name ODBCToolsPath
				if ($script:sqlcmd -and (Test-Path $script:sqlcmd)){
					$script:sqlcmd += "SQLCMD.EXE"
					return
				}
				else{
					$script:sqlcmd = $null
				}
			}
		}
	}
}

function Invoke-Command-With-Permission($message, $command){
	if ($doNotAsk){
		if ($print){
			Write-Host $command
			return $false
		}
		else{
			return $true
		}
	}
	else {
		Write-Host $message
		$readHost = Read-Host "(Y/N)"
		switch ($readHost) {
			Y {
				if ($print){ 
					Write-Host $command
					return $false
				}else{
					return $true
				}
			}
			Default { 
				Write-Host "No action taken" 
				return $false
			}
		}
	}
}


function Remove-WebApp-Database(){
	Remove-WebApp
	Remove-Database 
}

function Get-Value($key) {
	$keys = $key.split(":")

	foreach($k in $keys){
		if ($line -match "^$($k)=") {
			$value = $line.substring($k.length + 1)
			return $value
		}
	}
	return
}

function Drop-Database($database, $schema, $server){

	Get-SqlCmd
	if (-not $script:sqlcmd){
		Write-Warning "SQLcmd utillity not found. Database $($database) will not ne dropped."
		return
	}
	$command = $script:sqlcmd
	$arguments = "-S $($server) -E -Q ""DROP DATABASE [$($database)]"""
	if (Invoke-Command-With-Permission -message "Do you want to remove the $($database) database$($schemaText) from $($server)?" -command "$($command) $($arguments)"){
		Start-Process $script:sqlcmd -ArgumentList $arguments -NoNewWindow -Wait
	}
}

function Remove-WebApp(){
	if ($webRoot){
		if ($webRoot -match "http:\/\/(.*):8080\/(.*)\/servlet"){
			Remove-TomcatApp
		}
		else {
			Remove-IISApp
		}
	}
	$script:webRoot = $null
	$script:generator = $null
}

function Remove-TomcatApp(){
	Get-Tomcat
	if (-not $script:tomcat){
		Write-Warning "Tomcat path not found. Webapp $($matches[2]) will not ne removed."
		return
	}

	$appDir = $script:tomcat + "\webapps\" + $matches[2] 
	
	if (Test-Path $appDir){
		$command = "Remove-Item ""$($appDir)"" -recurse -force"
		if(Invoke-Command-With-Permission -message "Do you want to remove the $($appDir) Tomcat app ($($model))?" -command $command){
			Invoke-Expression $command
		}
	}
}

function Remove-IISApp(){
	$defaultWebSite = "Default Web Site"
	$webApps = Get-WebApplication -Site $defaultWebSite

	$webApp = $webRoot.Replace("http://localhost","")
	$webApp = $webApp.substring(0, $webApp.length - 1)
	
	if (-not ($script:sites.contains($webApp))){
		$script:sites += $webApp
		foreach($wa in $webApps){
			if ($wa.path -eq $webApp){
				$command = "Remove-WebApplication -Site '$($defaultWebSite)' -Name $($wa.path.substring(1))"
				if (Invoke-Command-With-Permission -message "Do you want to remove the $($webApp) IIS app ($($model))?" -command $command){
					Invoke-Expression $command
					return
				}
			}
		}
	}
}

function Remove-Database(){
	if ($dbms){
		if ($dbms -eq "SQL Server"){
			
			if ($dbName -and (-not ($script:dbs.contains($dbName)))) {
				$script:dbs += $dbName
				$schemaText = ""
				if ($schema){
					$schemaText = " ($($schema))"
				}

				Drop-Database -database $dbName -schema $schemaText -server $dbServer
			}
		}
		else {
			if (-not ($dbms.startswith("Android")) -and (-not ($dbms.startswith("SmartDevices"))) -and (-not ($dbms.startswith("Swift")))-and (-not ($dbms.startswith("Objective-C")))){
				Write-Warning "I'm not able to remove $($dbms) databases. You'll have to remove it yourself"
			}
		}
	}
	$script:schema = $null
	$script:dbServer = $null
	$script:dbName = $null
	$script:dbms = $null
}

function Remove-KnowledgeBase() {

	if (Test-Path "$($folder)\knowledgebase.connection"){
		[xml]$conn = Get-Content "$($folder)\knowledgebase.connection"
		$kbdb = $conn.ConnectionInformation.DBName
		$sqlInstance = $conn.ConnectionInformation.ServerInstance

		if ($kbdb) {
			Drop-Database -database $kbdb -server $sqlInstance
		}
	}
	else {
		Write-Error "No knwoledgebase.connection file found, don't know what to detach"
		return
	}

	$command = "Remove-Item -path $($folder) -recurse -force"
	if (Invoke-Command-With-Permission -message "Do you want to delete KB folder at $($folder)?" -command $command){
		Invoke-Expression $command
	}
}

$iniPath = "$($folder)\model.ini"
$sqlcmd = $null
$tomcat = $null

if (-not $justKB -and (Test-Path $iniPath)){
	$ini = Get-Content $iniPath
	$validModel = $false
	$dbs = @()
	$sites = @()
	foreach ($line in $ini) {

		if (-not $model){
			$model = Get-Value -key "Model"
			if ($model -and ($model -ne "Design")){
				$validModel = $true
			}
			else {
				$validModel = $false
			}
			if ($model){
				continue
			}
		}
		if ($validModel -and (-not $webRoot)){
			$webRoot = Get-Value -key "WebRoot"
			if ($webRoot){
				continue
			}
		}
		if ($validModel -and (-not $generator)){
			$generator = Get-Value -key "GeneratorType"
			if ($generator){
				continue
			}
		}
		if ($validModel -and (-not $dbServer)){
			$dbServer = Get-Value -key "CS_SERVER:CC_SERVER"
			if ($dbServer){
				continue
			}
		}
		if ($validModel -and (-not $dbName)){
			$dbName = Get-Value -key "CS_DBNAME:CC_DBNAME"
			if ($dbName){
				continue
			}
		}
		if ($validModel -and (-not $dbms)){
			$dbms = Get-Value -key "Description"
			if ($dbms){
				continue
			}
		}
		if ($validModel -and (-not $schema)){
			$schema = Get-Value -key "CS_SCHEMA:CC_SCHEMA"
			if ($schema){
				continue
			}
		}

		if ($line -match "^\[MODEL (.*)\]") {
			$model = $null
			$modelId = $matches[1]
		}

		if ($line -match "^\[PREFERENCES $($modelId).*") {
			if ($validModel){
				Remove-WebApp-Database	
			}
		}
	}
	Remove-WebApp-Database
}

Remove-KnowledgeBase

Return