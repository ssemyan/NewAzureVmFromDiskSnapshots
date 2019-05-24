# New Azure VM from Managed Disk Snapshots
This PowerShell script allows you to easily create a new VM from a snapshot of an OS and optionally a data disk. 

You can learn more about creating snapshots here: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/snapshot-copy-managed-disk

This is an easy way to replicate a VM and its associated data, for use elsewhere. You simply create a VM, attach a data disk if needed, set up the VM the way you would like it, and then stop it 
and create snapshots of the OS and data disk. You can then use these snapshots to create a new VM in a separate location within it's own VNet. Note: the username and password for the new VM will 
be the same as the VM the snapshot came from.

This code is based on the sample found here: https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-vm-from-snapshot

To use this file, first log in to your subscription:

    Login-AzureRmAccount -Subscription [Subscription Name]

Then, if necessary, create the resource group that will hold the new VM. The location specified will be the location used for the VM and it's associated resources.

    New-AzureRmResourceGroup -Name [Resource Group Name] -Location [location]

Finally, run the command specifying the paramters. For example: 

    powershell -f CreateVmFromSnaps.ps1 -resourceGroupName MyResourceGroup '
                                        -baseName NewVm '
                                        -snapResourceGroupName mastergroup'
                                        -osSnapshotName ossnapshot '
                                        -dataSnapshotName datasnapshot 

The details on how to use this script are below:

	NAME
	    CreateVmFromSnaps.ps1
	    
	SYNOPSIS
	    Uses disk snapshots for OS and data disks to create a new VM
	    
	    
	SYNTAX
	    CreateVmFromSnaps.ps1 [-resourceGroupName] <String> '
				  [-baseName] <String> '
				  [-snapResourceGroupName] <String> '
				  [-osSnapshotName] <String> '
				  [[-dataSnapshotName] <String>] '
				  [[-virtualMachineSize] <String>] '
				  [-Linux] '
				  [-Delete] '
				  [<CommonParameters>]
	    
	DESCRIPTION
	    Will create a new VM in its own VNET based on the OS and DataDisk snapshots.

	PARAMETERS
	    -resourceGroupName <String>
		The name of the resource group to create the new VM in. The resource group must already exist. 
		All new resources will be created in the location of this resource group.
		
	    -baseName <String>
		The name to use to prepend to all the resource names
		
	    -snapResourceGroupName <String>
		The name of the resource group where the snapshots of the disks are located
		
	    -osSnapshotName <String>
		The name of the snapshot to use for the OS disk
		
	    -dataSnapshotName <String>
		The name of snapshot to use for the data disk. If omitted, no data disk will be created
		
	    -virtualMachineSize <String>
		The size of the VM to create. If omitted will default to Standard_D4s_v3. 
		To get the vm sizes in a region use: Get-AzureRmVMSize -Location <location>
		
	    -Linux [<SwitchParameter>]
		If set, OS disk type is set to Linux. If omitted, the OS disk type will be set to Windows
		
	    -Delete [<SwitchParameter>]
		If set, any resources previously created that match the baseName entered will be deleted. 

	    <CommonParameters>
		This cmdlet supports the common parameters: Verbose, Debug,
		ErrorAction, ErrorVariable, WarningAction, WarningVariable,
		OutBuffer, PipelineVariable, and OutVariable. For more information, see 
		about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216). 
