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
$csvPath = "AzureDatabases.csv"

# Write the header row for the CSV file
"Subscription Name,SQL Server Name,Database Name,Resource Group,Number of Databases,Location,Total Consumed data in GB" | Out-File $csvPath -Encoding UTF8

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Set the subscription context
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all SQL servers in the subscription
    $sqlServers = Get-AzSqlServer

    foreach ($server in $sqlServers) {
        # Use Try-Catch to handle exceptions and continue with the next server
        try {
            # Get databases in the server
            $databases = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName

            # Calculate total size
            $totalSizeGB = 0
            foreach ($db in $databases) {
                $dbSize = (Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName -DatabaseName $db.DatabaseName).MaxSizeBytes / 1GB
                $totalSizeGB += $dbSize

                # Prepare data row for the CSV file with detailed info for each database
                $dataRow = '{0},{1},{2},{3},{4},{5},{6}' -f $subscription.Name, $server.ServerName, $db.DatabaseName, $server.ResourceGroupName, $databases.Count, $server.Location, [math]::Round($totalSizeGB, 2)
                $dataRow | Out-File $csvPath -Append -Encoding UTF8
            }
        } catch {
            Write-Host "Skipping SQL server due to an error: $($server.ServerName)"
            continue  # Skip to the next server
        }
    }
}

Write-Host "Data collection complete. Output written to $csvPath"
