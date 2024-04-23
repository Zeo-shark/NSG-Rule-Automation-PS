Import-Module Az.Network
Connect-AzAccount

# Function to add the rule to an NSG
function Add-NsgRule ($SubscriptionId, $ResourceGroup, $NsgName, $ruleDefinition) {
  
  $rule = New-AzNetworkSecurityRuleConfig -Name $ruleDefinition.Name -Description $ruleDefinition.Description -Priority $ruleDefinition.Priority -Direction $ruleDefinition.Direction -Access $ruleDefinition.Access -SourceAddressPrefix $ruleDefinition.SourceAddressPrefix -SourcePortRange $ruleDefinition.SourcePortRange -DestinationAddressPrefix $ruleDefinition.DestinationAddressPrefix -DestinationPortRange $ruleDefinition.DestinationPortRange -Protocol $ruleDefinition.Protocol
  
  Try {
    # Switch the context to the appropriate subscription
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop

    $nsg = Get-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $ResourceGroup -ErrorAction Stop
    $nsg.SecurityRules.Add($rule)
    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg -ErrorAction Stop
    Write-Host "Rule added to NSG: $NsgName ($ResourceGroup)"
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logEntry = "$timestamp, $($ruleDefinition.Name), $nsgName, $ResourceGroup, Added Successfully"
    $logFileName = "$($run_time)_$($ruleDefinition.Name)_add_success.log"
    Add-Content -Path ".\$logFileName" -Value $logEntry
  } Catch {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logEntry = "$timestamp, $($NsgName), $($_.Exception.Message)"
    $logFileName = "$($run_time)_$($ruleDefinition.Name)_add_fail.log"
    Add-Content -Path ".\$logFileName" -Value $logEntry

    Write-Error "Failed to add rule to NSG: $NsgName ($ResourceGroup) - $($_.Exception.Message)"
  }
}

$run_time = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$targetNsgs = Import-Csv -Path "./target_nsgs.csv" #provide your target_nsgs.csv path
$ruleDefinition = Import-Csv -Path "./nsg_rule_definitions.csv" # provide the nsg_rule_definitions.csv path

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
Write-Host "SourceAddressPrefix: $($ruleDefinition.SourceAddressPrefix)"
Write-Host "SourcePortRange: $($ruleDefinition.SourcePortRange)"
Write-Host "DestinationAddressPrefix: $($ruleDefinition.DestinationAddressPrefix)"
Write-Host "DestinationPortRange: $($ruleDefinition.DestinationPortRange)"
Write-Host "Protocol: $($ruleDefinition.Protocol)"
Write-Host "Access: $($ruleDefinition.Access)"
Write-Host "---------------------------------------------------------------------------------"
$userInput = Read-Host -Prompt 'Do you want to proceed with the addition? (yes/no)'

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
        $logFileName = "$($run_time)_$($ruleDefinition.Name)_add_fail.log"
        Add-Content -Path $logFileName -Value $errorMessage
        continue
      }

      Write-Host "About to add rule name: $name in NSG: $nsgName of rg: $resourceGroup"
      Write-Host "---------------------------------------------------------------------------------"
      Add-NsgRule -SubscriptionId $subscriptionId -ResourceGroup $resourceGroup -NsgName $nsgName -ruleDefinition $ruleDefinition 
  }
} else {
    Write-Host "Add operation cancelled by user."
}

Write-Host "Script completed!"


