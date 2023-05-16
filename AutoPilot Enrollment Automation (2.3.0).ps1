<#
# Script Written by Alexander Maria
# Version 2.3.0
# Last Modified 2/21/2022
######################################################
# Script Designed to automate AutoPilot Enrollment
# Exit Codes
# 1171 = Network connectivity fail
# 777  = Device onboarding trigger success
# 51 = Device data, Serial or HWID, not found/or accessable
#>


param
(
    [System.String]$Key,
    [System.String]$groupTag,
    [System.string]$clientid,
    [System.string]$TenantName
)


class Device_HWID_Info
{
   $serial = ((Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber)
   $hardwareid = ((Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData)
   $GroupTag = $groupTag
} # Class | END | Device_HWID_Info

Function Application_Token()
<# Generates request for the Applicaiton Token and returns the token value #>
{

    # Application (client) ID, tenant Name and secret
        #$clientid = ""
        #$TenantName = ""
    $ClientSecret = $key
    $resource = "https://graph.microsoft.com/"

    ##  Get access token

    $ReqTokenBody = 
    @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        client_Id     = $clientID
        Client_Secret = $clientSecret
     } 

    $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody

    return $TokenResponse.access_token
} # Function | END | Application_Token

Function Headers($TokenResponse)
<# Get & Set Header Token #>
{
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "Bearer $TokenResponse")

    return $headers
} # Function | END | Headers

function Get_Import_and_State($Headers)
<# Creates a check to see if the device hardware ID has been posted #>
{
    
    $autopilotprofile = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$($Device_HWID_Info.serial)')"
    $ProfileStatus = Invoke-RestMethod -Headers $Headers -Uri $autopilotprofile -Method Get

    return $ProfileStatus
} # Function | END | Get_Import_and_State

function Query_Profile_State($ProfileStatus)
<# Queries for enrollment status for device profile #>
{

    ##If 1  = The Serial Exists in the import // If 0 = The Serial does not Exist in the import
    if($ProfileStatus.'@odata.count' -eq 1)
    {
        Log("Profile Available")

        #Get Assigned State
        while(($ProfileStatus.value).deploymentProfileAssignmentStatus -ne "assignedUnkownSyncState")
        {
            $ProfileStatus = Get_Import_and_State(Headers(Application_Token))
            $ProfileStatusValue = ($ProfileStatus.value).deploymentprofileassignmentstatus
            Log("Current Profile Status - $ProfileStatusValue")
            start-sleep 15
            #Device is showing as having a record but the assigned state is not completed. Loop until Completed
        }

    Complete

    }
    else
    {
        Log("No Profile Existance Available - Creating Hardware Hash Import")
        Upload_HardwareHash(Headers(Application_Token))
        start-sleep 10
        #Get Assigned State
        while(($ProfileStatus.value).deploymentProfileAssignmentStatus -ne "assignedUnkownSyncState")
        {
            $ProfileStatus = Get_Import_and_State(Headers(Application_Token))
            $ProfileStatusValue = ($ProfileStatus.value).deploymentprofileassignmentstatus
            Log("Current Profile Status - $ProfileStatusValue")
            start-sleep 15
        }

    Complete

    }


} # Function | END | Query_Profile_State

function Upload_HardwareHash($Headers)
<# Using the Device Information Varibles and UPN it creates the dataset to create post for enrollment #>
{

    ## If it doesn't exist Upload device information to Autopilot service


    $body = "
    {
    ""@odata.type"": ""#microsoft.graph.importedWindowsAutopilotDeviceIdentity"",
    ""groupTag"": ""$($Device_HWID_Info.GroupTag)"",
    ""serialNumber"": ""$($Device_HWID_Info.serial)"",
    ""productKey"": """",
    ""hardwareIdentifier"": ""$($Device_HWID_Info.hardwareid)""
    }"

    $apiUrl = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/"
    $rest = Invoke-RestMethod -Headers $Headers -Uri $apiUrl -Body $body -Method Post -ContentType 'application/json'

    Log($rest)

} # Function | END | Upload_HardwareHash

function HTTPSGetTest()
<# Network test to https://google.com | Testing DNS and Internet Connectivity #>
{

    $request = [System.Net.WebRequest]::Create('https://graph.microsoft.com/')
    $response = $request.getResponse()

    If($response.StatusCode -eq 'OK')
    {
        Log("HTTP Success")
        return $response
    }
    else
    {
        Log("Error - 1171 - HTTP Failure")
        exit 1171
    }

} # Function | END | HTTPSGetTest

function Log($data)
{
    
    if(!(Test-Path "C:\Logs"))
    {
        mkdir "C:\Logs" -Force | Out-Null
    }

    $dte = (get-date -Format "MM-dd-yyyy HH:mm").ToString() + " : "
    $content = $dte + $data 
    Add-Content 'C:\Logs\AP_Onboarding.log'  $content
} # Function | END | Log

function Start_Script()
{

    if($groupTag -eq $null -or $groupTag -eq ""){$groupTag = "ASSIGNMENT_NEEDED"}
    Log("Logging Started")
    Log("GroupTag - $groupTag")


    if($Device_HWID_Info.serial)
    {
        Log("Serial - " + $Device_HWID_Info.serial)
    }
    else
    {
        log("Error - 51 - Serial data not found or accessable!")
        exit 51
    }

    if($Device_HWID_Info.hardwareid)
    {
        Log("Hardware Hash ID - " + $Device_HWID_Info.hardwareid)
    } 
    else
    {
        log("Error - 51 - HWID data not found or accessable!")
        exit 51
    }


   #HTTPSGetTest
    Query_Profile_State(Get_Import_and_State(Headers(Application_Token)))

} # Function | END | Start_Script

function Complete()
{
    Log("Completed")
    Add-Content 'C:\Logs\AP_Trigger.Success' "Success"
    exit 777 #JACKPOT
} # Function | END | Complete



$session = (New-CimSession)
$Device_HWID_Info = [Device_HWID_Info]::new()

Start_Script
