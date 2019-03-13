
param(
	[Parameter(Mandatory = $true)]
	[string]$folder,

	[Parameter(Mandatory = $false)]
	[switch]$batch,

	[Parameter(Mandatory = $false)]
	[string]$sqlInstance=".\SQL2016"

)

function Remove-KnowledgeBase() {

	Write-Host "About to remove $($kb_folder)"

	if (Test-Path "$($kb_folder)\knowledgebase.connection"){
		[xml]$conn = Get-Content "$($kb_folder)\knowledgebase.connection"
		$db = $conn.ConnectionInformation.DBName

		if ($db) {
			$sql = "drop database [$($db)]";
			sqlcmd -E -S $sqlInstance -Q $sql
			Write-Host $sql
		}
	}
	else {
		Write-Error "No knwoledgebase.connection file found, don't know what to detach"
		return;
	}

	Remove-Item $kb_folder -Recurse -Force
}

if (-not (Test-Path $folder)) {
	Write-Error "$($folder) is not a valid folder" -Category InvalidData -RecommendedAction "Send a valid Knowledge Base path"
	exit
}

$mdf = Get-ChildItem $folder -Filter *.gxw
if ($mdf) {
	$kb_folder = $folder
	Remove-KnowledgeBase
}
else {
	if ($batch) {
		$kbs = Get-ChildItem $folder -Directory	
		foreach ($kb in $kbs) {
			$kb_folder = $kb.FullName
			Remove-KnowledgeBase
		}
	}
	else {
		Write-Warning "The folder does not look like a valid Knowledge Base and you did not set the batch parameter"
	}
}

