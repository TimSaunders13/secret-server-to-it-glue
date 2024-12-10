$Script:application = "https://secretserver.domain.com"    # Or whatever your Url is.  Ours was hosted internally.
$Script:apiv1 = "$Script:application/api/v1"
$Script:apiv2 = "$Script:application/api/v2"
$Script:token = ""

################ PRIVATE FUNCTIONS ################
# Do NOT call these functions directly

function Get-Token
{
    [CmdletBinding()]
    param(
        [Switch] $UseTwoFactor
    )

    try {
        $creds = @{
            username = "SS_API"                     # You must create this user in Secret Server as an Application User
            password = "MyPerfectlySecurePassword"  # Set some password for this account.
            grant_type = "password"
        }
    
        $headers = $null
        If ($UseTwoFactor) {        
            Write-Debug "Call with UseTwoFactor"
            $headers = @{ 
                "OTP" = (Read-Host -Prompt "Enter your OTP for 2FA: ")        
            }    
        }
    
        Write-Debug "Calling Invoke-RestMethod oauth2/token"
        $response = Invoke-RestMethod "$Script:application/oauth2/token" -Method Post -Body $creds -Headers $headers;
    
        Write-Debug "Returning Token value"
        $Script:token = $response.access_token;
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function Get-FolderList
{
    [CmdletBinding()]
    param()
    try {
        Write-Debug "Checking for Token"
        if ($Script:token -eq "") {Get-Token}
    
        Write-Debug "Setting Headers"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $Script:token")
    
        Write-Debug "Setting Filters"
        $filters = "?filter.onlyIncludeRootFolders=true&take=999999&sortBy[0].direction=asc&sortBy[0].name=folderName"
    
        Write-Debug "Calling Invoke-RestMethod /folders"
        $results = Invoke-RestMethod "$Script:apiv1/folders$filters" -Headers $headers
    
        Write-Debug "Returning Results : $($results.total)" 
        return $results.records
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function Get-FolderNameById
{
    [CmdletBinding()]
    param(
        [int]$FolderId
    )

    try 
    {
        Write-Debug "Checking for Token"
        if ($Script:token -eq "") {Get-Token}

        Write-Debug "Setting Headers"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $Script:token")

        Write-Debug "Calling Invoke-RestMethod /folders/stub"
        $folderStub = Invoke-RestMethod "$Script:apiv1/folders/stub" -Headers $headers

        Write-Debug "Calling Invoke-RestMethod /folders"
        $folderInfo = Invoke-RestMethod "$Script:apiv1/folders/$FolderId" -Headers $headers

        Write-Debug "Returning Results"
        $RetVal = $folderInfo.folderName
        return $RetVal
    }
    catch 
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function Get-SecretOtp
{
    [CmdletBinding()]
    param(
        [int]$SecretId
    )

    try {
        Write-Debug "Checking for Token"
        if ($Script:token -eq "") {Get-Token}
    
        Write-Debug "Setting Headers"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $Script:token")
    
        Write-Debug "Calling Invoke-RestMethod /secret-detail/$SecretId/one-time-password-settings-key"
    
        Write-Debug "$Script:application/internals/secret-detail/$SecretId/one-time-password-settings-key"
        $result = Invoke-RestMethod "$Script:application/internals/secret-detail/$SecretId/one-time-password-settings-key" -Headers $headers
    
        Write-Debug "Returning result"
        return $result.key.value
    }
    catch {
        throw
    }
}


################ PUBLIC FUNCTIONS ################
# Call THESE functions

function Get-FolderContentsById
{
    [CmdletBinding()]
    param (
        # The name of the password to search for
        [Parameter(Mandatory = $true)]
        [string]$FolderId
    )

    try {
        Write-Debug "Checking for Token"
        if ($Script:token -eq "") {Get-Token}
    
        Write-Debug "Setting Headers"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $Script:token")
    
        Write-Debug "Setting Filters"
        $filters = "?filter.folderId=$FolderId&filter.includeInactive=false&filter.includeSubFolders=false&sortBy[0].direction=asc&sortBy[0].name=name&take=999999"
    
        Write-Debug "Calling Invoke-RestMethod /secrets"
        $results = Invoke-RestMethod "$Script:apiv1/secrets$filters" -Headers $headers
    
        Write-Debug "Returning Results : $($results.total)" 
        return $results.records
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function Get-SecretById
{
    [CmdletBinding()]
    param(
        [int]$SecretId,
        [switch]$MayHaveOtp = $false
    )

    try {
        Write-Debug "Checking for Token"
        if ($Script:token -eq "") {Get-Token}
    
        Write-Debug "Setting Headers"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $Script:token")
    
        Write-Debug "Calling Invoke-RestMethod /secrets"
        $Secret = Invoke-RestMethod "$Script:apiv1/secrets/$SecretId" -Headers $headers
    
        if ($MayHaveOtp) { 
            Write-Debug "Calling Get-SecretOtp"
            $SecretOtp = Get-SecretOtp $SecretId 
            $Secret | Add-Member -MemberType NoteProperty -Name "OtpValue" -Value $SecretOtp
        }
    
        Write-Debug "Returning Results"
        $RetVal = $Secret
    
        return $RetVal
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}
