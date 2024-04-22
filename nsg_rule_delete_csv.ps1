Connect-AzAccount

# Function to remove the rule from an NSG
function Remove-NsgRule ($SubscriptionId, $ResourceGroup, $NsgName, $ruleDefinition) {
  Try {
    # Switch the context to the appropriate subscription
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop

    # Get the Network Security Group
    $nsg = Get-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $ResourceGroup -ErrorAction Stop

    # Get the rule
    $rule = Get-AzNetworkSecurityRuleConfig -Name $ruleDefinition.Name -NetworkSecurityGroup $nsg -ErrorAction Stop

    # Check if the priority matches the user-provided priority
    if ($rule.Priority -eq $ruleDefinition.Priority) {
      # Remove the rule
      $nsg | Remove-AzNetworkSecurityRuleConfig -Name $ruleDefinition.Name -ErrorAction Stop
      $nsg | Set-AzNetworkSecurityGroup -ErrorAction Stop
      $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
      $dateOnly = $timestamp.Substring(0, 10)
      $logEntry = "$timestamp, $($ruleDefinition.Name), $nsgName, $ResourceGroup, Updated Successfully"
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_delete_success.log"
      $logFileName = $logFileName -replace '[\/:*?"<>|]', '_' # replace invalid characters
      Add-Content -Path ".\$logFileName" -Value $logEntry
      Write-Host "Rule removed from NSG: $NsgName ($ResourceGroup)"
    } else {
      Write-Error "Priority does not match for rule in NSG: $NsgName ($ResourceGroup)"
      $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
      $logEntry = "$timestamp, $($NsgName), Priority does not match for rule in NSG."
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_delete_fail.log"
      Add-Content -Path ".\$logFileName" -Value $logEntry
    }
  } Catch {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logEntry = "$timestamp, $($NsgName), $($_.Exception.Message)"
    $logFileName = "$($run_time)_$($ruleDefinition.Name)_delete_fail.log"
    Add-Content -Path ".\$logFileName" -Value $logEntry

    Write-Error "Failed to remove rule from NSG: $NsgName ($ResourceGroup) - $($_.Exception.Message)"
  }
}


$run_time = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
# Read the list of NSGs with Subscription Ids from a CSV file
$targetNsgs = Import-Csv -Path "./target_nsgs.csv"
# Read the list of NSG rule definitions from a CSV file
$ruleDefinition = Import-Csv -Path "./nsg_rule_definitions.csv"

if ([string]::IsNullOrEmpty($ruleDefinition.Name) -or [string]::IsNullOrEmpty($ruleDefinition.Description) -or [string]::IsNullOrEmpty($ruleDefinition.Access) -or [string]::IsNullOrEmpty($ruleDefinition.Protocol) -or [string]::IsNullOrEmpty($ruleDefinition.Direction) -or [string]::IsNullOrEmpty($ruleDefinition.Priority) -or [string]::IsNullOrEmpty($ruleDefinition.SourceAddressPrefix) -or [string]::IsNullOrEmpty($ruleDefinition.SourcePortRange) -or [string]::IsNullOrEmpty($ruleDefinition.DestinationAddressPrefix) -or [string]::IsNullOrEmpty($ruleDefinition.DestinationPortRange)) {
  $errorMessage = "One or more required properties in ruleDefinition are null or empty, please check and re-try the script"
  Write-Error $errorMessage
  throw $errorMessage
}

Write-Host "---------------------------------------------------------------------------------"
Write-Host "The following rule definition will be added in NSGs"
Write-Host "Name: $($ruleDefinition.Name)"
Write-Host "Priority: $($ruleDefinition.Priority)"
Write-Host "Direction: $($ruleDefinition.Direction)"
if ($ruleDefinition.Direction -ieq 'Inbound') {
  Write-Host "SourceAddressPrefix: $($ruleDefinition.SourceAddressPrefix)"
  Write-Host "SourcePortRange: $($ruleDefinition.SourcePortRange)"
  Write-Host "DestinationAddressPrefix: SubnetAddressPrefix"
  Write-Host "DestinationPortRange: $($ruleDefinition.DestinationPortRange)"
} elseif ($ruleDefinition.Direction -ieq 'Outbound') {
  Write-Host "SourceAddressPrefix: SubnetAddressPrefix"
  Write-Host "SourcePortRange: $($ruleDefinition.SourcePortRange)"
  Write-Host "DestinationAddressPrefix: $($targetNsgs.DestinationAddressPrefix)"
  Write-Host "DestinationPortRange: $($ruleDefinition.DestinationPortRange)"
}
Write-Host "Protocol: $($ruleDefinition.Protocol)"
Write-Host "Access: $($ruleDefinition.Access)"
Write-Host "---------------------------------------------------------------------------------"
$userInput = Read-Host -Prompt 'This is a irreversible operation, Do you want to proceed with the deletion? (yes/no)'
if ($userInput -ieq 'yes') {
  # Proceed with the update operation
  # Loop through each NSG and add the rule

  foreach ($targetNsg in $targetNsgs) {
    $subscriptionId = $targetNsg.SubscriptionId
    $resourceGroup = $targetNsg.ResourceGroup
    $nsgName = $targetNsg.Name
    $name= $ruleDefinition.Name

    # Check if variables are null or empty
    if ([string]::IsNullOrEmpty($subscriptionId) -or [string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($nsgName)) {
      $errorMessage = "One or more required variables are null or empty: subscriptionId = '$subscriptionId', resourceGroup = '$resourceGroup', nsgName = '$nsgName', please recheck and try again"
      Write-Error $errorMessage
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_delete_fail.log"
      Add-Content -Path $logFileName -Value $errorMessage
      continue
    }
  
    Write-Host "Deleting rule name: $name from NSG: $nsgName of rg: $resourceGroup"
    Write-Host "---------------------------------------------------------------------------------"
  
    foreach ($ruleDefinition in $ruleDefinition) {
      Remove-NsgRule -SubscriptionId $subscriptionId -ResourceGroup $resourceGroup -NsgName $nsgName -ruleDefinition $ruleDefinition
    }
  }
} else {
    Write-Host "delete operation cancelled by user."
}

Write-Host "Script completed!"
