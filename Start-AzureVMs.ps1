<#
    .SYNOPSIS
        This Azure Automation runbook automates the scheduled startup of specific virtual machines in an Azure subscription. 

    .DESCRIPTION
        The runbook implements a solution for scheduled power management of specific Azure virtual machines in a subscription.
		Each time it runs, the runbook looks for all virtual machines within the list. It then checks the current status of
        each, ensuring that the VMs are in the proper state before starting them if necessary.

    .PARAMETER  AzureCredentialName
        The name of the PowerShell credential asset in the Automation account that contains username and password
        for the account used to connect to target Azure subscription. This user must be configured as co-administrator
        of the subscription. 

        By default, the runbook will use the credential with name "Default Automation Credential"

        For for details on credential configuration, see:
        http://azure.microsoft.com/blog/2014/08/27/azure-automation-authenticating-to-azure-using-azure-active-directory/
    
    .PARAMETER  AzureSubscriptionName
        The name or ID of Azure subscription in which the resources will be created. By default, the runbook will use 
        the value defined in the Variable setting named "Default Azure Subscription"
   
    .INPUTS
        None.

    .OUTPUTS
        Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.
#>
  

workflow Start-AzureVMs 
{
	Param
	(
		[parameter(Mandatory=$false)]
		[String] $AzureAutomationCredential = "Use *Default Automation Credential* Asset",

		[parameter(Mandatory=$false)]
		[String] $AzureSubscriptionName = "Use *Default Azure Subscription* Variable Value",

		# Add variable for Azure VMs to be Started by this script
		[parameter(Mandatory=$false)]
		[String] $MachinesToStart = "Use *Scheduled VMs - Business Hours* Variable Value"
		
    	
	)
	
	# Retrieve credential name from variable asset if not specified
	if($AzureAutomationCredential -eq "Use *Default Automation Credential* asset")
	{
		$AutomationCredential = Get-AutomationPSCredential -Name "Default Automation Credential"
		if($AutomationCredential -eq $null)
		{
			Write-Output "ERROR: No automation credential name was specified, and no credential asset with name 'Default Automation Credential' was found. Either specify a stored credential name or define the default using a credential asset"
			Write-Output "Exiting runbook due to error"
			return
		}
	}
	else
	{
		$AutomationCredential = Get-AutomationPSCredential -Name $AzureAutomationCredential
		if($AutomationCredential -eq $null)
		{
			Write-Output "ERROR: Failed to get credential with name [$AzureAutomationCredential]"
			Write-Output "Exiting runbook due to error"
			return
		}
	}

	# Retrieve subscription name from variable asset if not specified
	if($AzureSubscriptionName -eq "Use *Default Azure Subscription* Variable Value")
	{
		$AzureSubscriptionName = Get-AutomationVariable -Name "Default Azure Subscription"
		if($AzureSubscriptionName.length -eq 0)
		{
			Write-Output "ERROR: No subscription name was specified, and no variable asset with name 'Default Azure Subscription' was found. Either specify an Azure subscription name or define the default using a variable setting"
			Write-Output "Exiting runbook due to error"
			return
		}
	}

	# Retrieve machines to Start variable asset if not specified
	if($MachinesToStart -eq "Use *Scheduled VMs - Business Hours* Variable Value")
	{
		$MachinesToStart = Get-AutomationVariable -Name "Scheduled VMs - Business Hours"
		if($MachinesToStart.length -eq 0)
		{
			Write-Output "ERROR: No variable asset with name 'Scheduled VMs - Business Hours' was found."
			Write-Output "Exiting runbook due to error"
			return
		}
	}
			
	# Wrapping script in an InlineScript activity, and passing any parameters for use within the InlineScript
	inlineScript
	{
		$AzureAutomationCredential = $using:AzureAutomationCredential
		$AzureSubscriptionName = $using:AzureSubscriptionName
		$MachinesToStart = $using:MachinesToStart
		
				
		# Note: Use of "Write-Output" is not recommended generally for recording informational or error messages
		# but is used here for ease of seeing everything in the "Output" pane in the Azure portal
		$currentTime = (Get-Date).ToUniversalTime()
		Write-Output "Runbook started"
		Write-Output "Current UTC/GMT time [$($currentTime.ToString("dddd, yyyy MMM dd HH:mm:ss"))]"
		Write-Output "Subscription: $AzureSubscriptionName"
		Write-Output "VMs: $MachinesToStart"
					
		# Connect to Azure (Start output)
		$output = Add-AzureAccount -Credential $Using:AutomationCredential 
	
		# Select subscription
		Select-AzureSubscription -SubscriptionName $Using:AzureSubscriptionName
		
		# Create the array of machine names which are listed to be started
		$Machines = $MachinesToStart.Split(",")
			
		# Process each VM from list of those to be started
		ForEach ($Machine in $Machines)
		{
			Write-Output "Getting Machine: $($Machine)"
			
			# Get the basic VM object and store it in a variable
			$VM = Get-AzureVM | where-object -Filterscript {$_.Name -eq $Machine}
			
			# Check if VM is already started
			if($VM.PowerState -eq "Started")
			{
				Write-Output "VM [$($VM.Name)] is already started."
			}
			else
			{
				# Get the full VM object and start the VM
				Write-Output "Starting VM: [$($VM.Name)]."
				Get-AzureVM -ServiceName $VM.ServiceName -Name $VM.Name | Start-AzureVM
			}
		}
		
		$endTime = (Get-Date).ToUniversalTime()
		Write-Output "Runbook completed"
		Write-Output "Current UTC/GMT time [$($endTime.ToString("dddd, yyyy MMM dd HH:mm:ss"))]"
		
	}
}
