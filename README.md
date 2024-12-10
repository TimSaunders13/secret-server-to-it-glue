# secretserver-to-it-glue
If you are running Thycotic or Delinea Secret Server and want to migrate to IT Glue, these PowerShell scripts should help figure out how to use both APIs.

## Disclaimer
> Let me start off by saying that I am not a PowerShell guru by any means.  I just needed to get my data migrated from Secret Server to IT Glue and thought I would share some of the code since there are a couple of Secret Server items that aren't in their documentation.  Specifically the mechanism to pull the OTP codes from within Secret Server.

**Notes:** 

- This project is shared `As Is`.  You will have to modify the scripts to match your situation.
- This project only migrates the Root folders in Secret Server and not sub-folders.


## Overview
I had been using Secret Server for a number of years in an MSP and had over 3500 secrets.  We decided to migrate all of this over to IT Glue and wanted to automate this as much as possible.  The documentation for Secret Server wasn't too bad, but there were a number of things that weren't in there or just weren't correct.  I think the IT Glue documentation was pretty good.

Since it took me a good bit of time to figure out a few of these items, I thought I would share my code, **as is**, with anyone who might need to make the same migration.  You will need to make a number of modifications to these scripts to make them match your configuration in Secret Server and IT Glue..


There are 6 script files and I will explain each here.

### _Testing.ps1

This file has a number of calls in it to lookup data from Secret Server and IT Glue.  For example, you will need to know the names of the fields (slugs) in IT Glue.  These can be pulled with the `Get-ITGlueFlexibleAsset` command.  There are other commands that I used when I created the scripts to migrate our data that I left in here in case you needed them for examples or needed them for your dev.

### ITGlue.ps1

This is the main IT Glue interaction file.  You will need to set your ITGlue_Base_Uri and ITGlue_Api_Key at the top of that script.  The meticulous part will be setting all of the field names in the functions to match the field name slugs in IT Glue.  This is where that **_Testing.ps1** comes in handy.  You can create a dummy item in IT Glue and then query that data to see what IT Glue calls the fields.

### MainMenu.ps1

This is the main file you should launch.  It gives you an option to Compare Secret Server folders to Organizations in IT Glue to ensure that they all exist in IT Glue.  The second option is to start migrating the data.

### Process-ClientComparison.ps1

This script loops through all of the folders in Secret Server and ensures that they exist as Organizations in IT Glue.

### Process-Migration.ps1

This script loops through all of the folders in Secret Server, alphabetizes them and then migrates the Secrets one by one to IT Glue.  There are a bunch of things that you will need to do to this script to match it to your organization.

1. You will need to create your Flexible Asset Types and make note of the ID in the IT Glue Url for each type.  This script has a number of places in it with a placeholder of <FATID-FROM-URL> that needs to be filled in with the appropriate ID.
2. There are two variables at the top of this script.  $Excluded_Clients allows you to tell the code to not migrate a folder.  $StartClient gives you the ability to restart processing after you have fixed issues and have it restart at a specific client.
3. You will need to modify the `Get-DoesSecretAllowOtp` function to return `$true` for any Secret Templates that you have setup to allow OTP.
4. In the `Start-FolderProcessing` function, you will need to set the Secret Template names here to match your Secret Templates.  You will also need to change the `Secret.items[#]` value to match you Secret Server Templates.
5. There are multiple switch options in the `Start-FolderProcessing` function.  Most of these have a FlexibleAssetTypeId with a temp value set to <FATID-FROM-URL>.  You will need to set these to match the IDs from your IT Glue implementation.
6. There are a few places in this script where I have commented out code that I used for testing.  For example, there are a couple of lines that allow you to only process specific Secret Server Template names so that you can get them configured and validated one at a time.

### SecretServer.ps1

This is the main Secret Server interaction file.  You will need to set your `$Script:application` variable to the domain of your Secret Server implementation.  You will also need to modify the Get-Token function and put in your Secret Server API username and password.  (I know.  I should have made these `$Script` variables, but I didn't.)


## Usage
Just launch the `MainMenu.ps1` file **AFTER** you have modified all of the necessary scripts.

**Hint:** When I ran my final run, I used `Start-Transcript` to have PowerShell render the results to a TXT file.


## Appology
I am sure that I have missed some things, but hopefully this gets you much further ahead than I was when I started this project.
