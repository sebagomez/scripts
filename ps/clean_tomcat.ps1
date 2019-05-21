$keep = @("host-manager", "manager", "ROOT")


$installed = Get-Item -Path 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\*\*'
if ($installed.Count -gt 1) {
	Write-Host "More than one Tomcat installation was found, type position for the desired instance"
	$i = 1
	foreach ($t in $installed) {
		Write-Host "$($i). $($t)"
		$i++
	}
	$selected = Read-Host "What is it gonna be?"
	$selected = [int]::Parse($selected) - 1
	$instance = $installed[$selected]
}
else {
	$instance = $installed
}

$tomcat = Get-ItemPropertyValue -Path "HKLM:\$($instance)" -Name InstallPath

if (-not $tomcat) {
	Write-Error "Tomcat installation not found"
	return
} 

Write-Host Cleaning Tomcat at $tomcat

$webAppsDir = $tomcat + "\webapps"
$files = Get-ChildItem $webAppsDir

foreach ($f in $files) {
	$name = $f.FullName.Replace($webAppsDir + "\" , "")
	if (!$keep.Contains($name)) {
		Write-Host "Removing $($f.FullName)"
		if ($f.PSIsContainer) {
			#Remove-Item $f.FullName -Recurse
		}
		else {
			#Remove-Item $f.FullName
		}
	}
	else {
		Write-Host "$($f.FullName) will not be deleted"
	}
}
