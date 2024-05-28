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
$csvPath = "AzureBlobStorageInfo.csv"

# Write the header row for the CSV file
"Subscription Name,Number of Containers,Location,Total Consumed data in GB" | Out-File $csvPath -Encoding UTF8

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Set the subscription context
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all storage accounts in the subscription
    $storageAccounts = Get-AzStorageAccount

    foreach ($account in $storageAccounts) {
        $ctx = $account.Context
        $totalSizeGB = 0
        $containerCount = 0

        # Use Try-Catch to handle exceptions and continue with the next storage account
        try {
            # Get containers and count them
            $containers = Get-AzStorageContainer -Context $ctx -WarningAction SilentlyContinue
            $containerCount = $containers.Count

            # Iterate through each container
            foreach ($container in $containers) {
                $blobs = Get-AzStorageBlob -Container $container.Name -Context $ctx -WarningAction SilentlyContinue
                foreach ($blob in $blobs) {
                    $totalSizeGB += $blob.Length / 1GB
                }
            }
        } catch {
            Write-Host "Skipping storage account due to an error: $($account.StorageAccountName)"
            continue  # Skip to the next storage account
        }

        # Prepare data row for the CSV file
        $dataRow = '{0},{1},{2},{3}' -f $subscription.Name, $containerCount, $account.PrimaryLocation, [math]::Round($totalSizeGB, 2)
        $dataRow | Out-File $csvPath -Append -Encoding UTF8
    }
}

Write-Host "Data collection complete. Output written to $csvPath"