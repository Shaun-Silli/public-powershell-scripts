# Check if the Az module is installed and install it if necessary
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Import the Az module
Import-Module Az
Import-Module ImportExcel

# Connect to Azure
Connect-AzAccount

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

# Initialize the Excel file
$excelPath = "AzureStorageInfo.xlsx"

# Function to write data to Excel
function WriteTo-Excel {
    param (
        [array]$data,
        [string]$sheetName
    )
    $data | Export-Excel -Path $excelPath -WorkSheetname $sheetName -AutoSize -Append
}

# Script 1: Collect Azure Blob Storage Info
$blobStorageData = @()
foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id
    $storageAccounts = Get-AzStorageAccount

    foreach ($account in $storageAccounts) {
        $ctx = $account.Context
        $totalSizeGB = 0
        $containerCount = 0

        try {
            $containers = Get-AzStorageContainer -Context $ctx -WarningAction SilentlyContinue
            $containerCount = $containers.Count

            foreach ($container in $containers) {
                $blobs = Get-AzStorageBlob -Container $container.Name -Context $ctx -WarningAction SilentlyContinue
                foreach ($blob in $blobs) {
                    $totalSizeGB += $blob.Length / 1GB
                }
            }
        } catch {
            Write-Host "Skipping storage account due to an error: $($account.StorageAccountName)"
            continue
        }

        $blobStorageData += [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            NumberOfContainers = $containerCount
            Location = $account.PrimaryLocation
            TotalConsumedDataGB = [math]::Round($totalSizeGB, 2)
        }

        # Write to Excel in batches to save memory
        if ($blobStorageData.Count -ge 100) {
            WriteTo-Excel -data $blobStorageData -sheetName "Blob Storage"
            $blobStorageData = @()  # Reset the array
        }
    }
}

# Write any remaining data to Excel
if ($blobStorageData.Count -gt 0) {
    WriteTo-Excel -data $blobStorageData -sheetName "Blob Storage"
}

# Script 2: Collect Azure Databases Storage Info
$databasesStorageData = @()
foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id
    $sqlServers = Get-AzSqlServer

    foreach ($server in $sqlServers) {
        try {
            $databases = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName
            $totalSizeGB = 0

            foreach ($db in $databases) {
                $dbSize = (Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName -DatabaseName $db.DatabaseName).MaxSizeBytes / 1GB
                $totalSizeGB += $dbSize

                $databasesStorageData += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    SQLServerName = $server.ServerName
                    DatabaseName = $db.DatabaseName
                    ResourceGroup = $server.ResourceGroupName
                    NumberOfDatabases = $databases.Count
                    Location = $server.Location
                    TotalConsumedDataGB = [math]::Round($totalSizeGB, 2)
                }

                # Write to Excel in batches to save memory
                if ($databasesStorageData.Count -ge 100) {
                    WriteTo-Excel -data $databasesStorageData -sheetName "Databases Storage"
                    $databasesStorageData = @()  # Reset the array
                }
            }
        } catch {
            Write-Host "Skipping SQL server due to an error: $($server.ServerName)"
            continue
        }
    }
}

# Write any remaining data to Excel
if ($databasesStorageData.Count -gt 0) {
    WriteTo-Excel -data $databasesStorageData -sheetName "Databases Storage"
}

# Script 3: Collect Azure VM Storage Info
$vmStorageData = @()
foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id
    $vms = Get-AzVM

    foreach ($vm in $vms) {
        try {
            $vmStatus = Get-AzVM -Status -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
            $powerState = $vmStatus.Statuses | Where-Object { $_.Code -match 'PowerState' } | Select-Object -ExpandProperty DisplayStatus

            if ($powerState -ne 'VM deallocated') {
                $vmStorageData += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    VMName = $vm.Name
                    VMSize = $vm.HardwareProfile.VmSize
                    OSType = $vm.StorageProfile.OsDisk.OsType
                    PowerState = $powerState
                    Location = $vm.Location
                }

                # Write to Excel in batches to save memory
                if ($vmStorageData.Count -ge 100) {
                    WriteTo-Excel -data $vmStorageData -sheetName "VM Storage"
                    $vmStorageData = @()  # Reset the array
                }
            }
        } catch {
            Write-Host "Skipping VM due to an error: $($vm.Name)"
            continue
        }
    }
}

# Write any remaining data to Excel
if ($vmStorageData.Count -gt 0) {
    WriteTo-Excel -data $vmStorageData -sheetName "VM Storage"
}

Write-Host "Data collection complete. Output written to $excelPath"
