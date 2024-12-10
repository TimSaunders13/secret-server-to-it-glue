$Excluded_Clients = ('_Temp', 'Z - Old Client Data')

Import-Module "./SecretServer.ps1" -Force
Import-Module "./ITGlue.ps1" -Force

Write-Host "> Getting list of root folders"

#Load Data from SecretServer
$SSFolderList = Get-FolderList

Write-Host "> Found $($SSFolderList.Count) folders to compare"

Foreach ($SSFolder in $SSFolderList)
{
    $FolderName = $SSFolder.folderName

    if (!($Excluded_Clients.Contains($FolderName))) {
        Write-Output "Processing: $FolderName"

        $OrganizationId = Get-ITGlueOrganizationIdByName $FolderName

        if (!$OrganizationId) {
            Write-Debug "Organization $FolderName does not exist"
        }
    }
}