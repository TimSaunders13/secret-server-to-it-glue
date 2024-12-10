$Script:ITGlue_Base_Uri = "https://api.itglue.com"
$Script:ITGlue_Api_Key = "YOUR-ITGLUE-API-KEY"
$Script:ITGlue_Api_Key_Secure = ConvertTo-SecureString $Script:ITGlue_Api_Key -AsPlainText -Force
$Script:ITGlue_JSON_Conversion_Depth = 5
$Script:ParentOrganizationId = 

#Region "Get Functions"

function Get-EscapedQueryString
{
    [CmdletBinding()]
    param (
        # The name of the password to search for
        [Parameter(Mandatory = $true)]
        [string]$QueryString
    )

    try {
        $RetVal = $QueryString.Replace(" ", "+").Replace(",", "%5C%2C").Replace("&", "%26")

        Return $RetVal
    } 
    catch {
        throw
    }
}

function Get-Headers
{

    try {
        $RetVal = @{
            "x-api-key" = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $Script:ITGlue_Api_Key_Secure).GetNetworkCredential().Password
            "Content-Type" = "application/vnd.api+json"
        }
    
        Return $RetVal
    } 
    catch {
        throw
    }

	$RetVal = @{
        "x-api-key" = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $Script:ITGlue_Api_Key_Secure).GetNetworkCredential().Password
        "Content-Type" = "application/vnd.api+json"
    }

	Return $RetVal
}

function Get-ITGlueDomainIdByName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [string]$DomainName
        )

        try {
            Write-Debug "Creating Headers"
            $headers = Get-Headers
    
            Write-Debug "Calling Invoke-RestMethod /organizations"
            $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/organizations/$OrganizationId/relationships/domains" -Method Get -Headers $headers
        
            # Check if any data is returned
            if ($response.data.Length -gt 0) {
                foreach ($DomainInfo in $response.data) {
                    if ($DomainInfo.attributes.name -eq $DomainName) { 
                        $RetVal = $DomainInfo.id
                        break
                    }
                }
            }
            else {
                Write-Debug "The Domain Name ($DomainName) was not found."
            }
        
            Return $RetVal
        } 
        catch {
            throw
        }
}

function Get-ITGlueOrganizationIdByName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OrganizationName
    )

    try {
        Write-Debug "Creating Filters"
        $CleanedFilter = Get-EscapedQueryString($OrganizationName)
        $filters = "?filter[name]=$CleanedFilter"
    
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Calling Invoke-RestMethod /organizations$filters"
        $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/organizations$filters" -Method Get -Headers $headers
    
        # Check if any organization data is returned
        if ($response.data.Length -gt 0) {
            $RetVal = $response.data[0].id
        }
        else {
            Write-Debug "No Organization found with the name '$OrganizationName'."
        }
    
        Return $RetVal
    } 
    catch {
        throw
    }
}

function Get-ITGluePasswordCategoryIdByName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PasswordCategoryName
    )

    try {
        Write-Debug "Creating Filters"
        $CleanedFilter = Get-EscapedQueryString($PasswordCategoryName)
        $filters = "?filter[name]=$CleanedFilter"
    
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Calling Invoke-RestMethod /organizations$filters"
        $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/password_categories$filters" -Method Get -Headers $headers
    
        # Check if any category data is returned
        if ($response.data.Length -gt 0) {
            $RetVal = $response.data[0].id
        }
        else {
            Debug "No Password Category found with the name '$PasswordCategoryName'."
        }
    
        Return $RetVal
    } 
    catch {
        throw
    }
}

#EndRegion "Get Functions"

function New-ITGlueFlexibleAsset_Email
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$EmailType,

        [Parameter(Mandatory = $true)]
        [int]$DomainId
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "type" = $EmailType
                        "service-location" = "Cloud"
                        "webmail-url" = "https://outlook.office.com"
                        "domain-s" = $DomainId
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Email added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_FirewallRouterPort
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Port,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$IpAddress,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SubnetMask,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Gateway
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "port" = $Port
                        "ip-address" = $IpAddress
                        "subnet-mask" = $SubnetMask
                        "gateway" = $Gateway
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_FirewallRouterPort added successfully with ID: $Fat"
        
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_FirewallRouter
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SerialNumber,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ManagementIpAddress,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ManagementPort,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$VpnPort,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [int[]]$Ports,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [int[]]$WirelessNetworks,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "manufacturer" = $Manufacturer
                        "model" = $Model
                        "serial-number-primary" = $SerialNumber
                        "management-ip-address-url" = $ManagementIpAddress
                        "management-port" = $ManagementPort
                        "vpn-port" = $VpnPort
                        "ports" = $Ports
                        "wireless-networks" = $WirelessNetworks
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_FirewallRouter added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_Licensing
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SoftwareTitle,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$LicensedTo,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$LicenseKey,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "manufacturer" = $Manufacturer
                        "software-title" = $SoftwareTitle
                        "licensed-to" = $LicensedTo
                        "license-key-s" = $LicenseKey
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Licensing added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_NetworkDevice
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SerialNumber,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ManagementIpAddressUrl,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "manufacturer" = $Manufacturer
                        "model" = $Model
                        "serial-number" = $SerialNumber
                        "management-ip-address-url" = $ManagementIpAddressUrl
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_NetworkDevice added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_Sabre
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
		[ValidateSet('Appliance', 'Direct (D2C)')]
        [string]$SabreType,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$D2CUserName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$D2CPassword,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ApplianceModel,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ApplianceIpAddress,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RootPassword,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UserPassword,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AdminWebGuiPassword,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EncryptionKey,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "sabre-type" = $SabreType
                        "customer-username" = $D2CUserName
                        "customer-password" = $D2CPassword
                        "appliance-model" = $ApplianceModel
                        "appliance-ip-address" = $ApplianceIpAddress
                        "root-password" = $RootPassword
                        "user-password" = $UserPassword
                        "admin-web-gui-password" = $AdminWebGuiPassword
                        "encryption-key" = $EncryptionKey
                        "username" = $UserName
                        "password" = $Password
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Sabre added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_Vendor
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$VendorName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AccountNumber,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$CallInPin,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SupportWebsiteUrl,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "vendor-name" = $VendorName
                        "account-number" = $AccountNumber
                        "call-in-pin" = $CallInPin
                        "support-website-url" = $SupportWebsiteUrl
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Vendor added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_Voice
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Serial,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InternalIp,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SubnetMask,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Gateway,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PasswordOnDevice,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "type" = $Type
                        "manufacturer" = $Manufacturer
                        "model" = $Model
                        "serial-number" = $Serial
                        "internal-ip-address" = $InternalIp
                        "subnet-mask" = $SubnedMast
                        "gateway" = $Gateway
                        "user-name" = $UserName
                        "password" = $Password
                        "password-on-device" = $PasswordOnDevice
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Voice added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_Vpn
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$IpAddressUrl,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SslPortNumber,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PreSharedKey,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "ip-address-url" = $IpAddressUrl
                        "ssl-port-number" = $SslPortNumber
                        "domain" = $Domain
                        "pre-shared-key" = $PreSharedKey
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_Voice added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_WirelessController
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ManagementIpAddressUrl,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SiteDeviceAuthUser,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SiteDeviceAuthPassword,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "name" = $Name
                        "manufacturer" = $Manufacturer
                        "model" = $Model
                        "management-ip-address-url" = $ManagementIpAddressUrl
                        "site-device-auth-user" = $SiteDeviceAuthUser
                        "site-device-auth-password" = $SiteDeviceAuthPassword
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_NetworkDevice added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGlueFlexibleAsset_WirelessNetwork
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

        [Parameter(Mandatory = $true)]
        [int]$FlexibleAssetTypeId,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Ssid,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EncryptionType,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PreSharedKey,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    try {
        Write-Debug "Creating Headers"
        $headers = Get-Headers

        if ($EncryptionType -eq "") {$EncryptionType = "None"}
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "flexible_assets"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "flexible_asset_type_id" = $FlexibleAssetTypeId
                    "traits" = @{
                        "ssid" = $Ssid
                        "encryption-type" = $EncryptionType
                        "pre-shared-key" = $PreSharedKey
                        "notes" = $Notes
                    }
                }
            } 
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /flexible_assets"
        $RetVal = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets" -Method Post -Headers $headers -Body $body
        
        $Fat = $RetVal.data.id
    
        Write-Debug "ITGlueFlexibleAsset_WirelessNetwork added successfully with ID: $Fat"
    
        Return $Fat
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGluePassword
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

		[Parameter(Mandatory = $true)]
        [string]$Name,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$OtpSecret,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Url,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Notes,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PasswordCategoryName
    )

    try {
        if (!$PasswordCategoryName -eq "") {
            Write-Debug "Looking up PasswordCategoryId"
            $PasswordCategoryId = Get-ITGluePasswordCategoryIdByName $PasswordCategoryName
        }

        if ( ($Url -match " ") -or ($Url -match ":") -or ($Url -match "\\") ) {
            # There is a Port or a space and IT Glue doesn't like Ports in Urls
            $Notes = "URL: $Url `r`n $Notes"
            $Url = ""
        }

        if ($Password -eq "") { $Password = "BlankAtMigration"}

        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "passwords"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "name" = $Name
                    "username" = $UserName
                    "password" = $Password
                    "otp_secret" = $OtpSecret
                    "url" = $Url
                    "notes" = $Notes
                    "password_category_id" = $PasswordCategoryId
                }
            }
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /passwords"
        $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/passwords" -Method Post -Headers $headers -Body $body
        
        Write-Debug "Password added successfully with ID: $($response.data.id)"
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

function New-ITGluePasswordEmbeded
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$OrganizationId,

		[Parameter(Mandatory = $true)]
        [string]$Name,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$OtpSecret,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Url,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$Notes,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
        [string]$PasswordCategoryName,

        [Parameter(Mandatory = $true)]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[ValidateSet('Configuration', 'Contact', 'Document', 'Domain', 'Location', 'SSL Certificate', 'Flexible Asset', 'Ticket')]
        [string]$ResourceType
    )

    try {
        if (!$PasswordCategoryName -eq "") {
            Write-Debug "Looking up PasswordCategoryId"
            $PasswordCategoryId = Get-ITGluePasswordCategoryIdByName $PasswordCategoryName
        }

        if ( ($Url -match " ") -or ($Url -match ":") -or ($Url -match "\\") ) {
            # There is a Port or a space and IT Glue doesn't like Ports in Urls
            $Notes = "URL: $Url `r`n $Notes"
            $Url = ""
        }

        if ($Password -eq "") { $Password = "BlankAtMigration"}
    
        Write-Debug "Creating Headers"
        $headers = Get-Headers
    
        Write-Debug "Creating Body"
        $body = @{
            "data" = @{
                "type" = "passwords"
                "attributes" = @{
                    "organization_id" = $OrganizationId
                    "name" = $Name
                    "username" = $UserName
                    "password" = $Password
                    "otp_secret" = $OtpSecret
                    "url" = $Url
                    "notes" = $Notes
                    "password_category_id" = $PasswordCategoryId
                    "resource_id" = $ResourceId
                    "resource_type" = $ResourceType
                }
            }
        } | ConvertTo-Json -Depth $Script:ITGlue_JSON_Conversion_Depth
    
        Write-Debug "Calling Invoke-RestMethod /passwords"
        $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/passwords" -Method Post -Headers $headers -Body $body
        
        Write-Debug "Password added successfully with ID: $($response.data.id)"
    } 
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}








################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
function Get-ITGlueFlexibleAsset
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$AssetId
    )

	Write-Debug "Creating Filters"
	$filters = "/$AssetId"

	Write-Debug "Creating Headers"
	$headers = Get-Headers

    Write-Debug "Calling Invoke-RestMethod /flexible_assets$filters"
    $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets$filters" -Method Get -Headers $headers

    # Check if any organization data is returned
    if ($response.data.Length -gt 0) {
        $RetVal = $response
    }
    else {
        Write-Debug "No Asset found with the id = '$AssetId'."
    }

    Return $RetVal
}

function Get-ITGlueFlexibleAssetFields
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AssetID
    )

	Write-Debug "Creating Headers"
	$headers = Get-Headers

    Write-Debug "Calling Invoke-RestMethod /flexible_assets$filters"
    $response = Invoke-RestMethod -Uri "$Script:ITGlue_Base_Uri/flexible_assets/$AssetID" -Method Get -Headers $headers

    # Check if any organization data is returned
    if ($response.data.Length -gt 0) {
        $RetVal = $response
    }
    else {
        Write-Debug "No Asset found with the id = '$AssetId'."
    }

    Return $RetVal
}
################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
################ USED DURING TESTING AND CONFIGURING FIELD NAMES #################
