#$ErrorActionPreference = "Stop"
$ErrorActionPreference = "Continue"

function Show-Menu {
    param(
        [string]$Title = "Main Menu"
    )

    Write-Host "=========================="
    Write-Host $Title
    Write-Host "=========================="
    Write-Host "1. Ensure All SS Folders have Client in ITG"
    Write-Host "2. Migrate Data"
    Write-Host "Q. Quit"
    Write-Host "=========================="
}

do {
    Show-Menu -Title "SecretServer > IT Glue Migration"

    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" {
            Write-Host "Ensuring All SS Folders have Client in ITG"
            .\Process-ClientComparison.ps1
        }
        "2" {
            .\Process-Migration.ps1
        }
        "Q" {
            Write-Host "Exiting..."
            break
        }
        default {
            Write-Host "Invalid choice. Please try again."
        }
    }
} until ($choice -eq "Q")