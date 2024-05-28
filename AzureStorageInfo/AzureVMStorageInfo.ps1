# Check if the Az module is installed and install it if necessary
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Import the Az module
Import-Module Az

# Connect to Azure
Connect-AzAccount

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

# Prepare the path for the CSV file
$csvPath = "AzureVMStorageInfo.csv"

# Write the header row for the CSV file
"Subscription Name,VM Name,VM Size,OS Type,Power State,Location" | Out-File $csvPath -Encoding UTF8

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Set the subscription context
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all VMs in the subscription
    $vms = Get-AzVM

    foreach ($vm in $vms) {
        # Try-Catch to handle exceptions and continue with the next VM
        try {
            # Get the power state of the VM
            $vmStatus = Get-AzVM -Status -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
            $powerState = $vmStatus.Statuses | Where-Object { $_.Code -match 'PowerState' } | Select-Object -ExpandProperty DisplayStatus

            # Check if the VM is not deallocated
            if ($powerState -ne 'VM deallocated') {
                # Prepare data row for the CSV file
                $dataRow = '{0},{1},{2},{3},{4},{5}' -f $subscription.Name, $vm.Name, $vm.HardwareProfile.VmSize, $vm.StorageProfile.OsDisk.OsType, $powerState, $vm.Location
                $dataRow | Out-File $csvPath -Append -Encoding UTF8
            }
        } catch {
            Write-Host "Skipping VM due to an error: $($vm.Name)"
            continue  # Skip to the next VM
        }
    }
}