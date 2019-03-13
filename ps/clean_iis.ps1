$defaultWebSite = "Default Web Site"
$webApps = Get-WebApplication -Site $defaultWebSite

foreach($wa in $webApps){
	Write-Host "$($wa.path) at $($wa.PhysicalPath) " -NoNewline
	if (Test-Path $wa.PhysicalPath){
		Write-Host "exists and will NOT be deleted"
	}
	else {
		Write-Host "does not exists and it's being deleted"
		$name = $wa.path.substring(1)
		Remove-WebApplication -Site $defaultWebSite -Name $name
	}
}