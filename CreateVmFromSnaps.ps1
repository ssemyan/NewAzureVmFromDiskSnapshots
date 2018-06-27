<#
 .SYNOPSIS
    Uses disk snapshots for OS and data disks to create a new VM

 .DESCRIPTION
    Will create a new VM in its own VNET based on the OS and DataDisk snapshots. 

 .PARAMETER resourceGroupName
    The name of the resource group to create the new VM in. The resource group must already exist. All new resources will be created in the location of this resource group. 

 .PARAMETER baseName
    The name to use to prepend to all the resource names

 .PARAMETER snapResourceGroupName
    The name of the resource group where the snapshots of the disks are located

 .PARAMETER osSnapshotName
    The name of the snapshot to use for the OS disk

 .PARAMETER dataSnapshotName
    The name of snapshot to use for the data disk. If omitted, no data disk will be created

 .PARAMETER dataSnapshotName
    The name of snapshot to use for the data disk. If omitted, no data disk will be created

 .PARAMETER virtualMachineSize
    The size of the VM to create. If omitted will default to Standard_D4s_v3. To get the vm sizes in a region use: Get-AzureRmVMSize -Location <location>

 .PARAMETER Linux
    If set, OS disk type is set to Linux. If omitted, the OS disk type will be set to Windows

 .PARAMETER Delete
    If set, any resources previously created that match the baseName entered will be deleted. 

#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $baseName,

 [Parameter(Mandatory=$True)]
 [string]
 $snapResourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $osSnapshotName,

 [string]
 $dataSnapshotName,

 [string]
 $virtualMachineSize = 'Standard_D4s_v3',

 [switch]
 $Linux,

 [switch]
 $Delete

)

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

$ErrorActionPreference = "Stop"

# Names of resources to create or delete
$nsgName = "${baseName}_nsg"
$subnetName = "${baseName}_subNet"
$vnetName = "${baseName}_vnet"
$ipName = "${baseName}_publicIp"
$virtualMachineName = "${baseName}_hostVm"
$osDiskName = "${baseName}_osdisk"
$dataDiskName = ''
$nicName = "${baseName}_nic"

if ($dataSnapshotName)
{
    $dataDiskName = "${baseName}_datadisk"
}

if ($Delete)
{
    Write-Host 'Warning - running this script will delete the following resources if they exist:'
    Write-Host "  VM                : $virtualMachineName"
    Write-Host "  NIC               : $nicName"
    Write-Host "  OS Disk           : $osDiskName"
    Write-Host "  Data Disk         : $dataDiskName"
    Write-Host "  Public IP Address : $ipName"
    Write-Host "  VNet              : $vnetName"
    Write-Host ""

    $confirm = Read-Host -Prompt 'Proceed with delete of above resources? yes [no]'
    if ($confirm -eq 'yes')
    {
        Write-Host 'Deleting VM...'
        Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $virtualMachineName -Force
        Write-Host 'Deleting OS Disk...'
        Remove-AzureRmDisk -ResourceGroupName $resourceGroupName -Name $osDiskName -Force
        if ($dataSnapshotName)
        {
            Write-Host 'Deleting Data Disk...'
            Remove-AzureRmDisk -ResourceGroupName $resourceGroupName -Name $dataDiskName -Force
        }
        Write-Host 'Deleting NIC...'
        Remove-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -Force
        Write-Host 'Deleting Networking...'
        Remove-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName -Force
        Write-Host 'Deleting NSG...'
        Remove-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName -Force
        Write-Host 'Deleting Public IP...'
        Remove-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName -Name $ipName -Force
    }
    return
}

$location = ''

# Get the location of the resource group
$grp = Get-AzureRmResourceGroup -Name $resourceGroupName
if(!$grp)
{
    Write-Error "Resource group '$resourceGroupName' not found in current subscription";
}
else{
    $location = $grp.Location
    Write-Host "Using resource group '$resourceGroupName' in location $location";
}

#Create Networking
Write-Host "Creating NSG $nsgName"
$rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName -SecurityRules $rdpRule

Write-Host "Creating subnet $subnetName"
$singleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix 10.0.0.0/24 -NetworkSecurityGroup $nsg

Write-Host "Creating vnet $vnetName"
$vnet = New-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $singleSubnet

#Create a public IP for the VM
Write-Host "Creating public IP $ipName"
$publicIp = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static

#Initialize virtual machine configuration with boot diagnostics disabled
Write-Host "Creating VM Config of size $virtualMachineSize with boot diagnostics disabled"
$VirtualMachine = New-AzureRmVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize | Set-AzureRmVMBootDiagnostics -disable

# Create and add OS disk
Write-Host "Creating os disk $osDiskName"
$snapshot = Get-AzureRmSnapshot -ResourceGroupName $snapResourceGroupName -SnapshotName $osSnapshotName
$diskConfig = New-AzureRmDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy
$disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $osDiskName

if ($Linux)
{
    Write-Host "Attaching OS disk as type Linux"
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Linux
} 
else {
    Write-Host "Attaching OS disk as type Windows"
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
}

# Create and add data disk if specified
if (!$dataSnapshotName)
{
    Write-Host "No data disk specified"
}
else {
    Write-Host "Creating data disk $dataDiskName"
    $snapshot2 = Get-AzureRmSnapshot -ResourceGroupName $snapResourceGroupName -SnapshotName $dataSnapshotName
    $diskConfig2 = New-AzureRmDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot2.Id -CreateOption Copy
    $disk2 = New-AzureRmDisk -Disk $diskConfig2 -ResourceGroupName $resourceGroupName -DiskName $dataDiskName
    $VirtualMachine = Add-AzureRmVMDataDisk -VM $VirtualMachine -Name "${baseName}_dataDisk" -ManagedDiskId $disk2.Id -CreateOption Attach -Lun 0
}

# Create NIC in the subnet of the virtual network and add to VM
Write-Host "Creating nic $nicName"
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

# Finally, create the virtual machine 
Write-Host "Creating VM $virtualMachineName"
New-AzureRmVM -VM $VirtualMachine -ResourceGroupName $resourceGroupName -Location $snapshot.Location

#Done
$IpAddress = $publicIp.IpAddress
Write-Host "VM created. Public IP: $IpAddress"