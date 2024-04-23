Import-Module Az.Network
Connect-AzAccount

# Function to update the rule in an NSG
function Update-NsgRule ($SubscriptionId, $ResourceGroup, $NsgName, $ruleDefinition) {
  Try {
    # Switch the context to the appropriate subscription
    Set-AzContext -SubscriptionId $SubscriptionId

    # Get the Network Security Group
    $nsg = Get-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $ResourceGroup -ErrorAction Stop

    $existingRule = Get-AzNetworkSecurityRuleConfig -Name $ruleDefinition.Name -NetworkSecurityGroup $nsg -ErrorAction Stop
    if ($existingRule) {
      # if existing PN= OLd PN-> Update
      # existing PN != OLd PN -> throw error
      if ($existingRule.Priority -eq $ruleDefinition.OldPriority) {
        $existingRule.Priority = $ruleDefinition.Priority
        $existingRule.Direction = $ruleDefinition.Direction
        $existingRule.SourceAddressPrefix = [System.Collections.Generic.List[string]]@($ruleDefinition.SourceAddressPrefix)
        $existingRule.DestinationAddressPrefix = [System.Collections.Generic.List[string]]@($ruleDefinition.DestinationAddressPrefix)
        $existingRule.SourcePortRange = [System.Collections.Generic.List[string]]@($ruleDefinition.SourcePortRange)
        $existingRule.DestinationPortRange = [System.Collections.Generic.List[string]]@($ruleDefinition.DestinationPortRange)
        $existingRule.Description = $ruleDefinition.Description
        $existingRule.Protocol = $ruleDefinition.Protocol
        $existingRule.Access = $ruleDefinition.Access

        # Update the existing rule
        $nsg | Set-AzNetworkSecurityRuleConfig -Name $existingRule.Name -Description $existingRule.Description -Access $existingRule.Access -Protocol $existingRule.Protocol -Direction $existingRule.Direction -Priority $existingRule.Priority -SourceAddressPrefix $existingRule.SourceAddressPrefix -SourcePortRange $existingRule.SourcePortRange -DestinationAddressPrefix $existingRule.DestinationAddressPrefix -DestinationPortRange $existingRule.DestinationPortRange -ErrorAction Stop

        # Save the changes to the Network Security Group
        $nsg | Set-AzNetworkSecurityGroup -ErrorAction Stop
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logEntry = "$timestamp, $($ruleDefinition.Name), $nsgName, $ResourceGroup, Updated Successfully"
        $logFileName = "$($run_time)_$($ruleDefinition.Name)_update_success.log"
        Add-Content -Path ".\$logFileName" -Value $logEntry
        Write-Host "Rule updated in NSG: $NsgName ($ResourceGroup)"
      }
    else{
      $errorMessage = "Cannot update the rule in NSG: $NsgName ($ResourceGroup) - Priority does not match for rule in NSG."
      Write-Error $errorMessage
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_update_fail.log"
      Add-Content -Path ".\$logFileName" -Value $logEntry
    }
  }
  else {
      Write-Error "Rule '$($ruleDefinition.Name)' not found in NSG: $NsgName ($ResourceGroup)"
      $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
      $logEntry = "$timestamp, $($NsgName), Rule not found in NSG."
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_update_fail.log"
      Add-Content -Path ".\$logFileName" -Value $logEntry
    }
  } 
  Catch {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logEntry = "$timestamp, $($NsgName), $($_.Exception.Message)"
    $logFileName = "$($run_time)_$($ruleDefinition.Name)_update_fail.log"
    Add-Content -Path ".\$logFileName" -Value $logEntry
    Write-Error "Failed to update rule in NSG: $NsgName ($ResourceGroup) - $($_.Exception.Message)"
  }
}



$run_time = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
# Read the list of NSGs with Subscription Ids from a CSV file
$targetNsgs = Import-Csv -Path "./target_nsgs.csv"
# Read the list of NSG rule definitions from a CSV file
$ruleDefinition = Import-Csv -Path "./nsg_rule_definitions_update.csv"

if ([string]::IsNullOrEmpty($ruleDefinition.Name) -or [string]::IsNullOrEmpty($ruleDefinition.Description) -or [string]::IsNullOrEmpty($ruleDefinition.Access) -or [string]::IsNullOrEmpty($ruleDefinition.Protocol) -or [string]::IsNullOrEmpty($ruleDefinition.Direction) -or [string]::IsNullOrEmpty($ruleDefinition.Priority) -or [string]::IsNullOrEmpty($ruleDefinition.SourceAddressPrefix) -or [string]::IsNullOrEmpty($ruleDefinition.SourcePortRange) -or [string]::IsNullOrEmpty($ruleDefinition.DestinationAddressPrefix) -or [string]::IsNullOrEmpty($ruleDefinition.DestinationPortRange) -or [string]::IsNullOrEmpty($ruleDefinition.OldPriority)) {
  $errorMessage = "One or more required properties in ruleDefinition are null or empty, please check and re-try the script"
  Write-Error $errorMessage
  throw $errorMessage
}

Write-Host "---------------------------------------------------------------------------------"
Write-Host "The following rule definition will be added in NSGs"
Write-Host "Name: $($ruleDefinition.Name)"
Write-Host "Priority: $($ruleDefinition.Priority)"
Write-Host "Direction: $($ruleDefinition.Direction)"
Write-Host "SourceAddressPrefix: $($ruleDefinition.SourceAddressPrefix)"
Write-Host "SourcePortRange: $($ruleDefinition.SourcePortRange)"
Write-Host "DestinationAddressPrefix: $($ruleDefinition.DestinationAddressPrefix)"
Write-Host "DestinationPortRange: $($ruleDefinition.DestinationPortRange)"
Write-Host "Protocol: $($ruleDefinition.Protocol)"
Write-Host "Access: $($ruleDefinition.Access)"
Write-Host "---------------------------------------------------------------------------------"
$userInput = Read-Host -Prompt 'Do you want to proceed with the Update? (yes/no)'
if ($userInput -ieq 'yes') {
  # Proceed with the update operation
  # Loop through each NSG and update the rule

  foreach ($targetNsg in $targetNsgs) {
    $subscriptionId = $targetNsg.SubscriptionId
    $resourceGroup = $targetNsg.ResourceGroup
    $nsgName = $targetNsg.Name
    $name= $ruleDefinition.Name

    # Check if variables are null or empty
    if ([string]::IsNullOrEmpty($subscriptionId) -or [string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($nsgName)) {
      $errorMessage = "One or more required variables are null or empty: subscriptionId = '$subscriptionId', resourceGroup = '$resourceGroup', nsgName = '$nsgName', please recheck and try again"
      Write-Error $errorMessage
      $logFileName = "$($run_time)_$($ruleDefinition.Name)_update_fail.log"
      Add-Content -Path $logFileName -Value $errorMessage
      continue
    }
    
    Write-Host "About to update rule name: $name in NSG: $nsgName of rg: $resourceGroup"
    Write-Host "---------------------------------------------------------------------------------"
    foreach ($ruleDefinition in $ruleDefinition) {
        Update-NsgRule -SubscriptionId $subscriptionId -ResourceGroup $resourceGroup -NsgName $nsgName -ruleDefinition $ruleDefinition 
    }
  }
} else {
    Write-Host "Update operation cancelled by user."
}


Write-Host "Script completed!"