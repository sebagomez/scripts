param([Parameter(Mandatory = $true)][string]$folder)

$iniPath = "$($folder)\model.ini"

function CleanUp(){
	$model = $null
	$targetPath = $null
	$webRoot = $null
	$generator = $null
	$dbServer = $null
	$dbName = $null
	$dbms = $null
}

function Get-Value($key) {
	if ($line -match "^$($key)=") {
		$value = $line.substring($key.length + 1)
	}

	return $value
}

function Remove-WebServer(){
	if ($webRoot){
		if ($webRoot -match "http:\/\/(.*):8080\/(.*)\/servlet"){
			Remove-TomcatApp
		}
		else {
			Remove-IISApp
		}
	}
}

function Remove-TomcatApp(){

	if (-not $tomcat){
		$tomcat = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\8.5\Tomcat8' -Name InstallPath
	}

	$appDir = $tomcat + "\webapps\" + $matches[2] 

	if (Test-Path $appDir){
		Write-Host "About to remove $($appDir)"
		Remove-Item $appDir -Recurse -WhatIf
	}
}

function Remove-IISApp(){
	$defaultWebSite = "Default Web Site"
	if (-not $webApps){
		$webApps = Get-WebApplication -Site $defaultWebSite
	}

	foreach($wa in $webApps){
		if ($wa.Name -eq $matches[2]){

			Write-Host "About to remove IIS app $($wa.name)"

			Remove-WebApplication -Site $defaultWebSite -Name $wa.name -WhatIf
			return
		}
	}

}

if (-Not (Test-Path($iniPath))) {
	Write-Host "model.ini file not found"
	return 
}

$ini = Get-Content $iniPath
$i = 1
foreach ($line in $ini) {

	if (-not $model){
		$model = Get-Value -key "Model"
	}
	if (-not $targetPath){
		$targetPath = Get-Value -key "TargetFullPath"
	}
	if (-not $webRoot){
		$webRoot = Get-Value -key "WebRoot"
	}
	if (-not $generator){
		$generator = Get-Value -key "GeneratorType"
	}
	if (-not $dbServer){
		$dbServer = Get-Value -key "CS_SERVER"
	}
	if (-not $dbName){
		$dbName = Get-Value -key "CS_DBNAME"
	}
	if (-not $dbms){
		$dbms = Get-Value -key "Description"
	}
	if ($line -match "^\[MODEL.*\]") {
		
		Write-Host "$($i):$($line)"
		if ($model) {
			Write-Host "Model:$($model) " -NoNewline
		}
		if ($targetPath){
			Write-Host "Path:$($targetPath) " -NoNewline
		}
		if ($webRoot){
			Write-Host "WebRoot: $($webRoot) " -NoNewline
		}
		if ($generator){
			Write-Host "Gen:$($generator) " -NoNewline
		}
		if ($dbServer){
			Write-Host "DBServer:$($dbServer) " -NoNewline
		}
		if ($dbName){
			Write-Host "DBName:$($dbName) " -NoNewline
		}
		if ($dbms){
			Write-Host "DBMS:$($dbms) " -NoNewline
		}

		
		Remove-WebServer

		CleanUp

		
		Write-Host ""
		$i++
	}
}