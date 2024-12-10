# NOTE:  <FATID-FROM-URL> is used in a number of locations below.  You will need to create the Flexible Asset Types and then lookup the FATID from the Url in IT Glue.

$Excluded_Clients = ('_Temp', 'Z - Old Client Data')
$StartClient = ""

Import-Module "./SecretServer.ps1" -Force
Import-Module "./ITGlue.ps1" -Force

function Get-CleanedNotes
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Notes
    )

    $RetVal = $Notes.Replace("`n", "<br>")

    Return $RetVal
}

function Get-DoesSecretAllowOtp
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SecretTemplateName
    )

    try {
        [switch]$RetVal = $false

        switch ($SecretTemplateName)
        {
            "Active Directory Account" { $Retval = $true }
            "Microsoft 365 Account" { $Retval = $true }
            "Network Device" { $Retval = $true }
            "Password" { $Retval = $true }
            "SonicWall Firewall" { $Retval = $true }
            "MSP Hosting Account" { $Retval = $true }
            "Web Password" { $Retval = $true }
        }
    
        Return $RetVal
    }
    catch {
        throw
    }
}

function Start-FolderProcessing
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderName,

        [Parameter(Mandatory = $true)]
        [int]$FolderId
    )

    try {
        # Get List of Objects in SS Folder
        $FolderContents = Get-FolderContentsById -FolderId $FolderId

        # Lookup OrganizationId from ITG
        $OrganizationId = Get-ITGlueOrganizationIdByName $FolderName

        Write-Debug "Found Organization: $OrganizationId"

        Foreach ($FolderItem in $FolderContents) {
            # Determine SecretTemplate
            $SecretTemplateName = $FolderItem.secretTemplateName
            $SecretName = $FolderItem.name
            $FatId = ""

#            If ($SecretTemplateName -eq "Password") {

            Write-Host ">> Processing Secret: $SecretName" -ForegroundColor Cyan

            $AllowsOtp = Get-DoesSecretAllowOtp -SecretTemplateName $SecretTemplateName

            if ($AllowsOtp) {
                $Secret = Get-SecretById -SecretId $FolderItem.id -MayHaveOtp
            } else {
                $Secret = Get-SecretById -SecretId $FolderItem.id
            }

            # Map SecretTemplate to ITG asset type
            switch ($SecretTemplateName)
            {
                "Active Directory Account" {
                    New-ITGluePassword -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[1].itemValue `
                        -Password $Secret.items[2].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[0].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[3].itemValue) `
                        -PasswordCategoryName "Active Directory"
                }

                "Contact Info" {
                    if (!$Secret.items[2].itemValue -eq "") {
                        $Notes = "Password: $($Secret.items[2].itemValue) >>> $($Secret.items[3].itemValue.Replace("`n", "<br>"))"
                    } else {
                        $Notes = $(Get-CleanedNotes $Secret.items[3].itemValue)
                    }

                    $FatId = New-ITGlueFlexibleAsset_Vendor -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -VendorName $SecretName `
                        -AccountNumber $Secret.items[1].itemValue `
                        -CallInPin "" `
                        -SupportWebsiteUrl $Secret.items[0].itemValue `
                        -Notes $Notes
                }

                "Encryption Key" {
                    New-ITGluePassword -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName "" `
                        -Password $Secret.items[0].itemValue `
                        -OtpSecret "" `
                        -Url "" `
                        -Notes $(Get-CleanedNotes $Secret.items[1].itemValue) `
                        -PasswordCategoryName "Encryption Key"
                }

                "Grandstream UCM" {
                    $FatId = New-ITGlueFlexibleAsset_Voice -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -Type "Local" `
                        -Manufacturer "Grandstream" `
                        -Model $Secret.items[1].itemValue `
                        -Serial $Secret.items[0].itemValue `
                        -InternalIp $Secret.items[5].itemValue `
                        -SubnetMask $Secret.items[7].itemValue `
                        -Gateway $Secret.items[8].itemValue `
                        -UserName $Secret.items[2].itemValue `
                        -Password $Secret.items[3].itemValue `
                        -PasswordOnDevice $Secret.items[4].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[12].itemValue)
                }

                "L2TP VPN" {
                    $Split = $Secret.items[1].itemValue -split ":"
                    $Url = $Split[0]
                    $Port = $Split[1]
                    $FatId = New-ITGlueFlexibleAsset_Vpn -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -IpAddressUrl $Url `
                        -SslPortNumber $Port `
                        -Domain "" `
                        -PreSharedKey $Secret.items[4].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[7].itemValue)

                    Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[5].itemValue `
                        -Password $Secret.items[6].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url "" `
                        -Notes "" `
                        -PasswordCategoryName "Other" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }

                "Microsoft 365 Account" {
                    # Note there is NO API to create a domain...  We manually created them and then looked them up.
                    $DomainName = $Secret.items[2].itemValue

                    if ( ($DomainName -match "onmicrosoft.com") -or ( $DomainName -eq "") ) {
                        # NO REAL DOMAIN FOR EMAIL
                        # MUST BE M365 APPS ONLY

                        New-ITGluePassword -OrganizationId $OrganizationId `
                            -Name $SecretName `
                            -UserName $Secret.items[3].itemValue `
                            -Password $Secret.items[4].itemValue `
                            -OtpSecret $Secret.OtpValue `
                            -Url $Secret.items[0].itemValue `
                            -Notes $(Get-CleanedNotes $Secret.items[6].itemValue) `
                            -PasswordCategoryName "Microsoft 365"
                    } else {
                        Write-Debug "Looking up DomainId for $DomainName"
                        $DomainId = Get-ITGlueDomainIdByName -OrganizationId $OrganizationId -DomainName $DomainName
                        Write-Debug "Located DomainId: $DomainId"
    
                        Write-Debug "Calling New-ITGlueFlexibleAsset_Email DomainId: $DomainId"
                        $FatId = New-ITGlueFlexibleAsset_Email -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -EmailType "Microsoft 365" `
                            -DomainId $DomainId
    
                        Write-Debug "Calling New-ITGluePasswordEmbeded with DomainId: $DomainId and EmailId: $FatId"
                        New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                            -Name $SecretName `
                            -UserName $Secret.items[3].itemValue `
                            -Password $Secret.items[4].itemValue `
                            -OtpSecret $Secret.OtpValue `
                            -Url $Secret.items[0].itemValue `
                            -Notes $(Get-CleanedNotes $Secret.items[6].itemValue) `
                            -PasswordCategoryName "Microsoft 365" `
                            -ResourceId $FatId `
                            -ResourceType "Flexible Asset"
                    }
                }

                "Network Device" {
                    switch ($Secret.items[10].itemValue)
                    {
                        "Firewall" {
                            $LAN = ""
                            $WAN = ""
                            $LanHasValue = $false
                            $WanHasValue = $false
                            [int[]]$PortArray = @()
    
                            if ($Secret.items[3].itemValue -ne "") {
                                $LanHasValue = $true
                                Write-Debug "Creating LanPort"
                                $LAN = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                                    -FlexibleAssetTypeId <FATID-FROM-URL> `
                                    -Name "LAN Port" `
                                    -Port "1" `
                                    -IpAddress $Secret.items[2].itemValue `
                                    -SubnetMask "" `
                                    -Gateway ""
                            }
    
                            if ( ($Secret.items[3].itemValue -ne "") -or ($Secret.items[4].itemValue -ne "") -or ($Secret.items[5].itemValue -ne "") ) {
                                $WanHasValue = $true
                                Write-Debug "Creating WanPort"
                                $WAN = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                                    -FlexibleAssetTypeId <FATID-FROM-URL> `
                                    -Name "WAN Port" `
                                    -Port "2" `
                                    -IpAddress $Secret.items[3].itemValue `
                                    -SubnetMask $Secret.items[4].itemValue `
                                    -Gateway $Secret.items[5].itemValue
                            }

                            if ($LanHasValue) { $PortArray += $LAN }
                            if ($WanHasValue) { $PortArray += $WAN }
    
                            Write-Debug "Creating Firewall with Ports: $PortArray"
                            $FatId = New-ITGlueFlexibleAsset_FirewallRouter -OrganizationId $OrganizationId `
                                -FlexibleAssetTypeId <FATID-FROM-URL> `
                                -Name $SecretName `
                                -Manufacturer "" `
                                -Model $Secret.items[0].itemValue `
                                -SerialNumber $Secret.items[1].itemValue `
                                -ManagementIpAddress $Secret.items[2].itemValue `
                                -ManagementPort "" `
                                -VpnPort "" `
                                -Ports $PortArray `
                                -WirelessNetworks @() `
                                -Notes $(Get-CleanedNotes $Secret.items[13].itemValue)
    
                            Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                            New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                -Name $SecretName `
                                -UserName $Secret.items[7].itemValue `
                                -Password $Secret.items[8].itemValue `
                                -OtpSecret $Secret.OtpValue `
                                -Url "" `
                                -Notes "" `
                                -PasswordCategoryName "Device" `
                                -ResourceId $FatId `
                                -ResourceType "Flexible Asset"

                            if ($Secret.items[9].itemValue) {
                                Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                                New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                    -Name "Enable: $SecretName" `
                                    -UserName "" `
                                    -Password $Secret.items[9].itemValue `
                                    -OtpSecret "" `
                                    -Url "" `
                                    -Notes "" `
                                    -PasswordCategoryName "Device" `
                                    -ResourceId $FatId `
                                    -ResourceType "Flexible Asset"
                                }

                        }
                    
                        "Switch" {
                            Write-Debug "Creating Switch"
                            $FatId = New-ITGlueFlexibleAsset_NetworkDevice -OrganizationId $OrganizationId `
                                -FlexibleAssetTypeId <FATID-FROM-URL> `
                                -Name $SecretName `
                                -Manufacturer "" `
                                -Model $Secret.items[0].itemValue `
                                -SerialNumber $Secret.items[1].itemValue `
                                -ManagementIpAddressUrl $Secret.items[2].itemValue `
                                -Notes $(Get-CleanedNotes $Secret.items[13].itemValue)
    
                            Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                            New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                -Name $SecretName `
                                -UserName $Secret.items[7].itemValue `
                                -Password $Secret.items[8].itemValue `
                                -OtpSecret $Secret.OtpValue `
                                -Url $Secret.items[2].itemValue `
                                -Notes "" `
                                -PasswordCategoryName "Device" `
                                -ResourceId $FatId `
                                -ResourceType "Flexible Asset"

                            if ($Secret.items[9].itemValue) {
                                Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                                New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                    -Name "Enable: $SecretName" `
                                    -UserName "" `
                                    -Password $Secret.items[9].itemValue `
                                    -OtpSecret "" `
                                    -Url "" `
                                    -Notes "" `
                                    -PasswordCategoryName "Device" `
                                    -ResourceId $FatId `
                                    -ResourceType "Flexible Asset"
                                }
                        }

                        "UPS" {
                            Write-Debug "Creating UPS"
                            $FatId = New-ITGlueFlexibleAsset_NetworkDevice -OrganizationId $OrganizationId `
                                -FlexibleAssetTypeId <FATID-FROM-URL> `
                                -Name $SecretName `
                                -Manufacturer "" `
                                -Model $Secret.items[0].itemValue `
                                -SerialNumber $Secret.items[1].itemValue `
                                -ManagementIpAddressUrl $Secret.items[2].itemValue `
                                -Notes $(Get-CleanedNotes $Secret.items[13].itemValue)
    
                            Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                            New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                -Name $SecretName `
                                -UserName $Secret.items[7].itemValue `
                                -Password $Secret.items[8].itemValue `
                                -OtpSecret $Secret.OtpValue `
                                -Url $Secret.items[2].itemValue `
                                -Notes "" `
                                -PasswordCategoryName "Device" `
                                -ResourceId $FatId `
                                -ResourceType "Flexible Asset"
                        }

                        { ($_ -eq "Other") -or ($_ -eq "") } {
                            Write-Debug "Creating Other Network Device"
                            $FatId = New-ITGlueFlexibleAsset_NetworkDevice -OrganizationId $OrganizationId `
                                -FlexibleAssetTypeId <FATID-FROM-URL> `
                                -Name $SecretName `
                                -Manufacturer "" `
                                -Model $Secret.items[0].itemValue `
                                -SerialNumber $Secret.items[1].itemValue `
                                -ManagementIpAddressUrl $Secret.items[2].itemValue `
                                -Notes $(Get-CleanedNotes $Secret.items[13].itemValue)
    
                            Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                            New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                -Name $SecretName `
                                -UserName $Secret.items[7].itemValue `
                                -Password $Secret.items[8].itemValue `
                                -OtpSecret $Secret.OtpValue `
                                -Url $Secret.items[2].itemValue `
                                -Notes "" `
                                -PasswordCategoryName "Device" `
                                -ResourceId $FatId `
                                -ResourceType "Flexible Asset"
                        }

                        "Printer" {
                            Write-Debug "Creating Printer"
                            $FatId = New-ITGlueFlexibleAsset_NetworkDevice -OrganizationId $OrganizationId `
                                -FlexibleAssetTypeId <FATID-FROM-URL> `
                                -Name $SecretName `
                                -Manufacturer "" `
                                -Model $Secret.items[0].itemValue `
                                -SerialNumber $Secret.items[1].itemValue `
                                -ManagementIpAddressUrl $Secret.items[2].itemValue `
                                -Notes $(Get-CleanedNotes $Secret.items[13].itemValue)
    
                            Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                            New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                                -Name $SecretName `
                                -UserName $Secret.items[7].itemValue `
                                -Password $Secret.items[8].itemValue `
                                -OtpSecret $Secret.OtpValue `
                                -Url $Secret.items[2].itemValue `
                                -Notes "" `
                                -PasswordCategoryName "Device" `
                                -ResourceId $FatId `
                                -ResourceType "Flexible Asset"
                        }
                    }
                }

                "Password" {
                    New-ITGluePassword -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[1].itemValue `
                        -Password $Secret.items[3].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[0].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[4].itemValue) `
                        -PasswordCategoryName ""
                }

                "Product License Key" {
                    $FatId = New-ITGlueFlexibleAsset_Licensing -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Manufacturer "Other" `
                        -SoftwareTitle "$($Secret.items[1].itemValue) --- $SecretName" `
                        -LicensedTo $Secret.items[0].itemValue `
                        -LicenseKey $Secret.items[2].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[4].itemValue)
                }

                "Router with WiFi" {
                    $Ssid1 = ""
                    $Ssid2 = ""
                    $Ssid3 = ""
                    $Ssid1HasValue = $false
                    $Ssid2HasValue = $false
                    $Ssid3HasValue = $false
                    $Lan = ""
                    $Wan = ""
                    $LanHasValue = $false
                    $WanHasValue = $false
                    [int[]]$SsidArray = @()
                    [int[]]$PortArray = @()

                    if ( $Secret.items[9].itemValue -ne "" ) {
                        $Ssid1HasValue = $true
                        Write-Debug "Creating SSID1"
                        $Ssid1 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[9].itemValue `
                            -EncryptionType $Secret.items[10].itemValue `
                            -PreSharedKey $Secret.items[11].itemValue `
                            -Notes "VLAN: $($Secret.items[12].itemValue)"
                    }

                    if ( $Secret.items[13].itemValue -ne "" ) {
                        $Ssid2HasValue = $true
                        Write-Debug "Creating SSID2"
                        $Ssid2 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[13].itemValue `
                            -EncryptionType $Secret.items[14].itemValue `
                            -PreSharedKey $Secret.items[15].itemValue `
                            -Notes "VLAN: $($Secret.items[16].itemValue)"
                    }

                    if ( $Secret.items[17].itemValue -ne "" ) {
                        $Ssid3HasValue = $true
                        Write-Debug "Creating SSID3"
                        $Ssid3 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[17].itemValue `
                            -EncryptionType $Secret.items[18].itemValue `
                            -PreSharedKey $Secret.items[19].itemValue `
                            -Notes "VLAN: $($Secret.items[20].itemValue)"
                    }

                    if ( $Secret.items[4].itemValue -ne "" ) {
                        $LanHasValue = $true
                        Write-Debug "Creating LanPort"
                        $Lan = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Name "LAN Port" `
                            -Port "1" `
                            -IpAddress $Secret.items[4].itemValue `
                            -SubnetMask "" `
                            -Gateway ""
                    }

                    if ( ($Secret.items[5].itemValue -ne "") -or ($Secret.items[6].itemValue -ne "") -or ($Secret.items[7].itemValue -ne "") ) {
                        $WanHasValue = $true
                        Write-Debug "Creating WanPort"
                        $Wan = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Name "WAN Port" `
                            -Port "2" `
                            -IpAddress $Secret.items[5].itemValue `
                            -SubnetMask $Secret.items[6].itemValue `
                            -Gateway $Secret.items[7].itemValue
                    }

                    if ($Ssid1HasValue) { $SsidArray += $Ssid1 }
                    if ($Ssid2HasValue) { $SsidArray += $Ssid2 }
                    if ($Ssid3HasValue) { $SsidArray += $Ssid3 }

                    if ($LanHasValue) { $PortArray += $Lan }
                    if ($WanHasValue) { $PortArray += $Wan }

                    Write-Debug "Creating Firewall with Ports: $PortArray"
                    $FatId = New-ITGlueFlexibleAsset_FirewallRouter -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -Manufacturer "" `
                        -Model $Secret.items[2].itemValue `
                        -SerialNumber $Secret.items[1].itemValue `
                        -ManagementIpAddress $Secret.items[4].itemValue `
                        -ManagementPort "" `
                        -VpnPort "" `
                        -Ports $PortArray `
                        -WirelessNetworks $SsidArray `
                        -Notes $(Get-CleanedNotes $Secret.items[23].itemValue)

                    Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[0].itemValue `
                        -Password $Secret.items[3].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url "" `
                        -Notes "" `
                        -PasswordCategoryName "Device" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }

                "Sabre BDR Appliance" {
                    $FatId = New-ITGlueFlexibleAsset_Sabre -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -SabreType "Appliance" `
                        -D2CUserName "" `
                        -D2CPassword "" `
                        -ApplianceModel $Secret.items[0].itemValue `
                        -ApplianceIpAddress $Secret.items[1].itemValue `
                        -RootPassword $Secret.items[2].itemValue `
                        -UserPassword $Secret.items[3].itemValue `
                        -AdminWebGuiPassword $Secret.items[4].itemValue `
                        -EncryptionKey $Secret.items[8].itemValue `
                        -UserName $Secret.items[6].itemValue `
                        -Password $Secret.items[7].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[5].itemValue)
            
                    Write-Debug "Calling New-ITGluePasswordEmbeded for iDRAC with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name "iDRAC-iLo-IPMI" `
                        -UserName $Secret.items[10].itemValue `
                        -Password $Secret.items[11].itemValue `
                        -OtpSecret "" `
                        -Url $Secret.items[9].itemValue `
                        -Notes "" `
                        -PasswordCategoryName "iDRAC / iLO" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }
    
                "Sabre Direct (D2C)" {
                    $FatId = New-ITGlueFlexibleAsset_Sabre -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -SabreType "Direct (D2C)" `
                        -D2CUserName $Secret.items[0].itemValue `
                        -D2CPassword $Secret.items[1].itemValue `
                        -ApplianceModel "" `
                        -ApplianceIpAddress "" `
                        -RootPassword "" `
                        -UserPassword "" `
                        -AdminWebGuiPassword "" `
                        -EncryptionKey $Secret.items[3].itemValue `
                        -UserName "" `
                        -Password "" `
                        -Notes $(Get-CleanedNotes $Secret.items[2].itemValue)
                }

                "SonicWall Firewall" {
                    $X0HasValue = $false
                    $X1HasValue = $false
                    $X20HasValue = $false
                    [int[]]$PortArray = @()

                    if ( ($Secret.items[4].itemValue -ne "") -or ($Secret.items[5].itemValue -ne "") ) {
                        $X0HasValue = $true
                        Write-Debug "Creating X0"
                        $X0 = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Name "X0" `
                            -Port "0" `
                            -IpAddress $Secret.items[4].itemValue `
                            -SubnetMask $Secret.items[5].itemValue `
                            -Gateway ""
                    }

                    if ( ($Secret.items[6].itemValue -ne "") -or ($Secret.items[7].itemValue -ne "") -or ($Secret.items[8].itemValue -ne "") ) {
                        $X1HasValue = $true
                        Write-Debug "Creating X1"
                        $X1 = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Name "X1" `
                            -Port "1" `
                            -IpAddress $Secret.items[6].itemValue `
                            -SubnetMask $Secret.items[7].itemValue `
                            -Gateway $Secret.items[8].itemValue
                    }

                    if ( ($Secret.items[9].itemValue -ne "") -or ($Secret.items[10].itemValue -ne "") -or ($Secret.items[11].itemValue -ne "") ) {
                        $X20HasValue = $true
                        Write-Debug "Creating X20"
                        $X20 = New-ITGlueFlexibleAsset_FirewallRouterPort -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Name "X20" `
                            -Port "20" `
                            -IpAddress $Secret.items[9].itemValue `
                            -SubnetMask $Secret.items[10].itemValue `
                            -Gateway $Secret.items[11].itemValue
                    }

                    if ($X0HasValue) { $PortArray += $X0 }
                    if ($X1HasValue) { $PortArray += $X1 }
                    if ($X20HasValue) { $PortArray += $X20 }

                    Write-Debug "Creating SonicWall Firewall with Ports: $Ports"
                    $FatId = New-ITGlueFlexibleAsset_FirewallRouter -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -Manufacturer "SonicWall" `
                        -Model $Secret.items[0].itemValue `
                        -SerialNumber $Secret.items[1].itemValue `
                        -ManagementIpAddress $Secret.items[4].itemValue `
                        -ManagementPort $Secret.items[12].itemValue `
                        -VpnPort $Secret.items[13].itemValue `
                        -Ports $PortArray `
                        -WirelessNetworks @() `
                        -Notes $(Get-CleanedNotes $Secret.items[16].itemValue)

                    Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name "SonicWall" `
                        -UserName $Secret.items[2].itemValue `
                        -Password $Secret.items[3].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url "" `
                        -Notes "" `
                        -PasswordCategoryName "Device" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }

                "MSP Hosting Account" {
                    $FatId = New-ITGlueFlexibleAsset_Vendor -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -VendorName $SecretName `
                        -AccountNumber $Secret.items[3].itemValue `
                        -CallInPin $Secret.items[4].itemValue `
                        -SupportWebsiteUrl $Secret.items[0].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[5].itemValue)

                    Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name "MSP Domains" `
                        -UserName $Secret.items[1].itemValue `
                        -Password $Secret.items[2].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[0].itemValue `
                        -Notes "See Vendors" `
                        -PasswordCategoryName "Domain/DNS" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }

                "Ubiquiti Unifi Controller & APs" {
                    $Ssid1 = ""
                    $Ssid2 = ""
                    $Ssid3 = ""
                    $Ssid4 = ""
                    $Ssid1HasValue = $false
                    $Ssid2HasValue = $false
                    $Ssid3HasValue = $false
                    $Ssid4HasValue = $false
                    [int[]]$SsidArray = @()

                    if ( $Secret.items[6].itemValue -ne "" ) {
                        $Ssid1HasValue = $true
                        Write-Debug "Creating SSID1"
                        $Ssid1 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[6].itemValue `
                            -EncryptionType $Secret.items[7].itemValue `
                            -PreSharedKey $Secret.items[8].itemValue `
                            -Notes "VLAN: $($Secret.items[9].itemValue)"
                    }

                    if ( $Secret.items[10].itemValue -ne "" ) {
                        $Ssid2HasValue = $true
                        Write-Debug "Creating SSID2"
                        $Ssid2 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[10].itemValue `
                            -EncryptionType $Secret.items[11].itemValue `
                            -PreSharedKey $Secret.items[12].itemValue `
                            -Notes "VLAN: $($Secret.items[13].itemValue)"
                    }

                    if ( $Secret.items[14].itemValue -ne "" ) {
                        $Ssid3HasValue = $true
                        Write-Debug "Creating SSID3"
                        $Ssid3 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[14].itemValue `
                            -EncryptionType $Secret.items[15].itemValue `
                            -PreSharedKey $Secret.items[16].itemValue `
                            -Notes "VLAN: $($Secret.items[17].itemValue)"
                    }

                    if ( $Secret.items[18].itemValue -ne "" ) {
                        $Ssid4HasValue = $true
                        Write-Debug "Creating SSID4"
                        $Ssid4 = New-ITGlueFlexibleAsset_WirelessNetwork -OrganizationId $OrganizationId `
                            -FlexibleAssetTypeId <FATID-FROM-URL> `
                            -Ssid $Secret.items[18].itemValue `
                            -EncryptionType $Secret.items[19].itemValue `
                            -PreSharedKey $Secret.items[20].itemValue `
                            -Notes "VLAN: $($Secret.items[21].itemValue)"
                    }

                    if ($Ssid1HasValue) { $SsidArray += $Ssid1 }
                    if ($Ssid2HasValue) { $SsidArray += $Ssid2 }
                    if ($Ssid3HasValue) { $SsidArray += $Ssid3 }
                    if ($Ssid4HasValue) { $SsidArray += $Ssid4 }

                    Write-Debug "Creating Wireless Controller with SSIDs: $SsidArray"
                    $FatId = New-ITGlueFlexibleAsset_WirelessController -OrganizationId $OrganizationId `
                        -FlexibleAssetTypeId <FATID-FROM-URL> `
                        -Name $SecretName `
                        -Manufacturer "Ubiquiti" `
                        -Model "" `
                        -ManagementIpAddressUrl $Secret.items[1].itemValue `
                        -SiteDeviceAuthUser $Secret.items[4].itemValue `
                        -SiteDeviceAuthPassword $Secret.items[5].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[22].itemValue)

                    Write-Debug "Calling New-ITGluePasswordEmbeded with FatId: $FatId"
                    New-ITGluePasswordEmbeded -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[2].itemValue `
                        -Password $Secret.items[3].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[1].itemValue `
                        -Notes "" `
                        -PasswordCategoryName "Device" `
                        -ResourceId $FatId `
                        -ResourceType "Flexible Asset"
                }

                "VMware ESX/ESXi" {
                    New-ITGluePassword -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[1].itemValue `
                        -Password $Secret.items[2].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[0].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[3].itemValue) `
                        -PasswordCategoryName "Application"
                }

                "Web Password" {
                    New-ITGluePassword -OrganizationId $OrganizationId `
                        -Name $SecretName `
                        -UserName $Secret.items[1].itemValue `
                        -Password $Secret.items[2].itemValue `
                        -OtpSecret $Secret.OtpValue `
                        -Url $Secret.items[0].itemValue `
                        -Notes $(Get-CleanedNotes $Secret.items[3].itemValue) `
                        -PasswordCategoryName "Web/FTP"
                }
            }
#            }
        }
    }
    catch {
        throw
    }
}

Write-Host ""
Write-Host ""
Write-Host "Processing Started: $(Get-Date -Format "MM-dd-yyyy HH:mm:ss")" -ForegroundColor Blue

Write-Host "> Getting list of root folders"

#Load Data from SecretServer
$SSFolderList = Get-FolderList

Write-Host "> Found $($SSFolderList.Count) folders to migrate"

Foreach ($SSFolder in $SSFolderList)
{
    $FolderName = $SSFolder.folderName
    $FolderId = $SSFolder.id


<#
    # TEMP FOR TESTING
    # TEMP FOR TESTING
    # TEMP FOR TESTING     _Import Testing is the test Organization I used in IT Glue for Dev testing
    if($FolderName -eq "Testing Client Folder in Secret Server") {
        Write-Host "Processing FolderName: $FolderName" -ForegroundColor Green
        Start-FolderProcessing -FolderName "_Import Testing" -FolderId $FolderId
    }
    # TEMP FOR TESTING
    # TEMP FOR TESTING
    # TEMP FOR TESTING
#>

if (!($Excluded_Clients.Contains($FolderName))) {

        if ($FolderName -ge $StartClient) {
            Write-Output "Processing FolderName: $FolderName"

            Start-FolderProcessing -FolderName $FolderName -FolderId $FolderId
        }
    }
}

Write-Host "Processing Completed: $(Get-Date -Format "MM-dd-yyyy HH:mm:ss")" -ForegroundColor Blue
Write-Host ""
Write-Host ""
