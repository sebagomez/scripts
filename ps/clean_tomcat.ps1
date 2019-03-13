$keep = @("host-manager","manager","ROOT")

$tomcat = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\8.5\Tomcat8' -Name InstallPath

Write-Host Cleaning Tomcat at $tomcat

$webAppsDir = $tomcat + "\webapps"
$files = Get-ChildItem $webAppsDir

foreach ($f in $files) {
	$name = $f.FullName.Replace($webAppsDir + "\" , "")
	if (!$keep.Contains($name)) {
		Write-Host "Removing $($f.FullName)"
		if ($f.PSIsContainer){
			Remove-Item $f.FullName -Recurse
		}
		else {
			Remove-Item $f.FullName
		}
	}
	else {
		Write-Host "$($f.FullName) will not be deleted"
	}
}
