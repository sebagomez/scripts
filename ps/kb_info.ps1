param([Parameter(Mandatory = $true)][string]$folder, [Parameter(Mandatory = $false)][bool]$doNotAsk)

if ($folder.endsWith("model.ini")){
	$iniPath = $folder
}else{
	$iniPath = "$($folder)\model.ini"
}

function Invoke-Command-With-Permission($message, $command){
	if ($doNotAsk){
		Invoke-Expression $command
	}
	else {
		Write-Host $message
		$readHost = Read-Host "(Y/N)"
		switch ($readHost) {
			Y { Invoke-Expression $command  }
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
		Invoke-Command-With-Permission -message "Do you want to remove the $($appDir) Tomcat app ($($model))?" -command "Remove-Item $($appDir) -Recurse -WhatIf"
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
				Invoke-Command-With-Permission -message "Do you want to remove the $($webApp) IIS app ($($model))?" -command "Remove-WebApplication -Site $($defaultWebSite) -Name $($wa.path.substring(1)) -WhatIf"
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
				#sqlcmd -E -S $dbServer -Q $sql
				$schemaText = ""
				if ($schema){
					$schemaText = " ($($schema))"
				}
				Invoke-Command-With-Permission -message "Do you want to remove the $($dbName) database$($schemaText) from $($dbServer) ($($model))?" -command "Write-Host sqlcmd -E -S $($dbServer) -Q $($sql)"
			}
		}
		else {
			if (-not ($dbms.startswith("Android")) -and (-not ($dbms.startswith("SmartDevices"))) -and (-not ($dbms.startswith("Swift")))){
				Write-Warning "I'm not able to remove $($dbms) databases. You'll have to remove it yourself"
			}
		}
	}
	$script:schema = $null
	$script:dbServer = $null
	$script:dbName = $null
	$script:dbms = $null
}

if (-Not (Test-Path($iniPath))) {
	Write-Host "model.ini file not found"
	return 
}

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