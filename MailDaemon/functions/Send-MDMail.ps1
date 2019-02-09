﻿function Send-MDMail
{
	<#
		.SYNOPSIS
			Queues current email for delivery.

		.DESCRIPTION
			Uses the data prepared by Set-MDMail or Add-MDMailContent and queues the email for delivery.

		.PARAMETER TaskName
			Name of the task that is sending the email.
			Used in the name of the file used to queue messages in order to reduce likelyhood of accidental clash.
		
		.EXAMPLE
			PS C:\> Send-MDMail -TaskName "Logrotate"

			Queues the currently prepared email under the name "Logrotate"
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$TaskName
	)
	
	begin
	{
		# Ensure the pickup patch exists
		if (-not (Test-Path (Get-PSFConfigValue -FullName 'MailDaemon.Daemon.MailPickupPath')))
		{
			try { $null = New-Item -Path (Get-PSFConfigValue -FullName 'MailDaemon.Daemon.MailPickupPath') -ItemType Directory -Force -ErrorAction Stop }
			catch
			{
				Stop-PSFFunction -String 'Send-MDMail.Folder.CreationFailed' -StringValues (Get-PSFConfigValue -FullName 'MailDaemon.Daemon.MailPickupPath') -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true
			}
		}
	}
	process
	{
		# Don't send an email if nothing was set up
		if (-not $script:mail) { Stop-PSFFunction -String 'Send-MDMail.Email.NotRegisteredYet' -EnableException $true -Cmdlet $PSCmdlet }

		$script:mail['Taskname'] = $TaskName
		
		# Send the email
		Write-PSFMessage -String 'Send-MDMail.Email.Sending' -StringValues $TaskName -Target $TaskName
		try { [PSCustomObject]$script:mail | Export-Clixml -Path "$(Get-PSFConfigValue -FullName 'MailDaemon.Daemon.MailPickupPath')\$($TaskName)-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').clixml" -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -String 'Send-MDMail.Email.SendingFailed' -StringValues $TaskName -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true -Target $TaskName
		}

		# Reset email, now that it is queued
		$script:mail = $null

		try { Start-ScheduledTask -TaskName MailDaemon -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -String 'Send-MDMail.Email.TriggerFailed' -StringValues $TaskName -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true -Target $TaskName
		}
	}
}
