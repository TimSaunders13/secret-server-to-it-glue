Import-Module "./SecretServer.ps1" -Force
Import-Module "./ITGlue.ps1" -Force

# These are all calls I made while troubleshooting.  
# I figured I would leave them as you may find them useful.


#Get-ITGlueOrganizationIdByName "ORGANIZATION NAME"

#$Global:SecretInfo = Get-SecretById -SecretId 8888

#$Global:FAT = Get-ITGlueFlexibleAssetTypes

#$Global:Data = Get-ITGlueFlexibleAsset -AssetId 91911979

#$Global:Result = Get-ITGlueFlexibleAssetFields -AssetId 123456789