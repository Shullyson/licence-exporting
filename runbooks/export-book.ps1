# Essential Modules (PowerShell 7.2):
# Microsoft.Graph.Authentication
# Microsoft.Graph.Beta.Users
# Microsoft.Graph.Identity.DirectoryManagement
# All on module version 2.25.0

#testing
# Get current date and convert to specific time zone
$Date = Get-Date 
$Date = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Date, [System.TimeZoneInfo]::Local.Id, 'W. Europe Standard Time')
$FileDate = Get-Date $Date -UFormat %Y%m%d
$Date = Get-Date $Date -UFormat %Y-%m-%d

# Connect to Azure
Write-Output "Connecting to Azure"
Connect-AzAccount -Identity
Write-Output "Connected to Azure"

# Retrieve the variable from the Automation Account
$keyVaultName = Get-AutomationVariable -Name "KeyVaultName"
$secretName = Get-AutomationVariable -Name "SecretName"
$storageAccountName = Get-AutomationVariable -Name "StorageAccountName"
$containerName = Get-AutomationVariable -Name "ContainerName"

# Retrieve the SAS token from Key Vault
$sasToken = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText

# Remove leading '?' if present
if ($sasToken.StartsWith("?")) {
    $sasToken = $sasToken.Substring(1)
}

# Connect to Microsoft Graph with necessary scopes
Write-Output "Connecting to Microsoft Graph"
Connect-MgGraph -Identity
Write-Output "Connected to Microsoft Graph"

Get-MgContext

# Get tenant details
Write-Output "Retrieving tenant details"
$tenantDetails = Get-MgOrganization
$TenantId = $tenantDetails.Id
Write-Output "Tenant details retrieved"

# Initialize result arrays
$Result = @()
$ResultTemp = @()
$Header = New-Object -TypeName System.Object

# Define properties to retrieve for each user
$AADValues = @("Id","AccountEnabled") #,"CreationType"

# Add properties to header object
$Header | Add-Member -MemberType NoteProperty -Name "Date" -Value "Date"
foreach($AADValue in $AADValues)
{
    $Header | Add-Member -MemberType NoteProperty -Name $AADValue -Value $AADValue
}

# Retrieve user list from Microsoft Graph Beta endpoint
Write-Output "Retrieving user list"
$Userlist = Get-MgBetaUser -All | Where-Object {($PSItem.CreationType -eq $null) -or ($PSItem.assignedLicenses -ne $null)} | Select Id, AccountEnabled, assignedLicenses
Write-Output "User list retrieved"

# Output total number of users found
Write-Output "Total Users: $($Userlist.count)"

# Process each user to extract license information
foreach($User in $Userlist)
{
    $Licenses = $User | select -ExpandProperty assignedLicenses
    foreach($License in $Licenses)
    {
        $Header | Add-Member -MemberType NoteProperty -Name $License.SkuId -Value $License.SkuId -ErrorAction Ignore
        $User | Add-Member -MemberType NoteProperty -Name $License.SkuId -Value "Enabled"
    }
    $User.PSObject.Properties.Remove("assignedLicenses")
    $ResultTemp += $User
}

# Combine header and user data into result array
$Result += $Header
$Result += $ResultTemp

# Define file name for CSV export
$FileName = "$($FileDate)_$($TenantId)_O365_AnonymousReport.csv"

# Remove existing file if it exists
if (Test-Path $FileName) {
    Remove-Item $FileName -Force
}

# Export result array to CSV file
$Result | Export-Csv $FileName -Delimiter ";" -Encoding UTF8 -NoTypeInformation

# Define storage account connection string and container name

$StorageBaseUrl = "https://$storageAccountName.blob.core.windows.net"
$BlobUri = "$StorageBaseUrl/$containerName/$FileName?$sasToken"

$Headers = @{
    "x-ms-blob-type" = "BlockBlob"
}

$CurrentPath = Get-Location
$LocalCsvPath = Join-Path -Path $CurrentPath -ChildPath $FileName
$FileBytes = [System.IO.File]::ReadAllBytes($LocalCsvPath)

if (-Not (Test-Path $LocalCsvPath)) {
    Write-Output "Local file does not exist: $LocalCsvPath"
    exit
}

# Create storage context using SAS token
$Context = New-AzStorageContext -SASToken $SASToken -StorageAccountName $storageAccountName -WarningAction Ignore
Set-AzCurrentStorageAccount -Context $Context | Out-Null

# Get current path and define local CSV path
$CurrentPath = Get-Location
$LocalCsvPath = Join-Path -Path $CurrentPath -ChildPath $FileName

# Upload file to blob storage using Set-AzStorageBlobContent
Set-AzStorageBlobContent -Context $Context -Container $containerName -Blob $FileName -File $LocalCsvPath -Force

# Disconnect from Microsoft Graph if connected
if (Get-MgContext) {
    Disconnect-MgGraph
    Write-Output "Disconnected from Microsoft Graph"
} else {
    Write-Output "No application to sign out from"
}


