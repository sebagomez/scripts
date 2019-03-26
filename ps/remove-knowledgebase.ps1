param(
	[Parameter(Mandatory = $true)]
	[string]$folder, 
	
	[Parameter(Mandatory = $false)]
	[bool]$doNotAsk, 
	
	[Parameter(Mandatory = $false)]
	[string]$sqlInstance=".\SQL2016",

	[Parameter(Mandatory = $false)]
	[bool]$justKB,
	
	[Parameter(Mandatory = $false)]
	[bool]$print
)

$iniPath = "$($folder)\model.ini"

function Invoke-Command-With-Permission($message, $command){
	if ($doNotAsk){
		if ($print){
			Write-Host "$($command)"
		}
		else{
			Invoke-Expression $command
		}
	}
	else {
		Write-Host $message
		$readHost = Read-Host "(Y/N)"
		switch ($readHost) {
			Y {
				if ($print){ 
					Write-Host "$($command)"
				}else{
					Invoke-Expression $command  
				}
			}
			Default { Write-Host "Nothing removed" }
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
	if (-not $tomcat){
		$tomcat = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\8.5\Tomcat8' -Name InstallPath
	}

	$appDir = $tomcat + "\webapps\" + $matches[2] 
	
	if (Test-Path $appDir){
		Invoke-Command-With-Permission -message "Do you want to remove the $($appDir) Tomcat app ($($model))?" -command "Remove-Item $($appDir) -Recurse"
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
				Invoke-Command-With-Permission -message "Do you want to remove the $($webApp) IIS app ($($model))?" -command "Remove-WebApplication -Site '$($defaultWebSite)' -Name $($wa.path.substring(1))"
				return
			}
		}
	}
}

function Remove-Database(){
	if ($dbms){
		if ($dbms -eq "SQL Server"){
			if ($dbName -and (-not ($script:dbs.contains($dbName)))) {
				$script:dbs += $dbName
				$sql = "drop database [$($dbName)]";
				$schemaText = ""
				if ($schema){
					$schemaText = " ($($schema))"
				}
				Invoke-Command-With-Permission -message "Do you want to remove the $($dbName) database$($schemaText) from $($dbServer) ($($model))?" -command 'sqlcmd -E -S $($dbServer) -Q "$($sql)"'
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

		if ($kbdb) {
			$sql = "drop database [$($kbdb)]";
			Invoke-Command-With-Permission -message "Do you want to delete the KB database at $($kbdb) ($($sqlInstance))?" -command 'sqlcmd -E -S $($sqlInstance) -Q "$($sql)"'
		}
	}
	else {
		Write-Error "No knwoledgebase.connection file found, don't know what to detach"
		return
	}

	Invoke-Command-With-Permission -message "Do you want to delete KB folder at $($folder)?" -command "Remove-Item $($folder) -Recurse -Force"
}

if (-not $justKB -and (-Not (Test-Path($iniPath)))) {
	Write-Host "model.ini file not found"
	return 
}

if (-not $justKB){
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