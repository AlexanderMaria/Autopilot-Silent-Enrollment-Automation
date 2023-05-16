# Autopilot-Silent-Enrollment-Automation
 .ps1 | Silent script that can be deployed with paramaters to enroll a target machine into autopilot.
 
 
Script Written by Alexander Maria
Version 2.3.0
Last Modified 2/21/2022
######################################################
Script Designed to automate AutoPilot Enrollment
Exit Codes
1171 = Network connectivity fail
777  = Device onboarding trigger success
51 = Device data, Serial or HWID, not found/or accessable

######################################################

Script needs to be fed Paramaters in order to function. This can be done at runtime or supplied during deployment setup.

Arguments required:
Key = The client secret to your AAD tenant
groupTag = The Grouptag of which you want to assign the device
clientID = The Tenant Client ID
TenantName = the GUID of the tenant


Example:

AutoPilot Enrollment Automation (2.3.0).ps1  -key {ClientSecret} -groupTag {TestTag} -clientID {Tenant Client ID} -TenantName {Tenant GUID}



