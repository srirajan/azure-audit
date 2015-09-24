<#
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

.SYNOPSIS 
    This script will query an Azure accounts and provide a summary of the setup.
.DESCRIPTION
    Works only for Classic/Native Azure model
    This not tested against Azure Resource Manager
.EXAMPLE

.NOTES
#>

Get-AzureSubscription -OutVariable subs >$null
foreach ($sub in $subs) {
    "---------------------------------------------------------------------"
    "Subscription:" + $sub.SubscriptionName + "," + $sub.SubscriptionId
    "---------------------------------------------------------------------"
    Set-AzureSubscription -SubscriptionName  $sub.SubscriptionName

    "** List of VMs **"
    Get-AzureVM -OutVariable vms >$null
    "Service Name,VM Name,DNS Name,Power State,Status,Instance Size,Virtual Network"
    foreach ($vm in $vms) {
        $vm.ServiceName + "," +
        $vm.Name + ","  +
        $vm.DNSName + ","  +
        $vm.PowerState + "," +
        $vm.Status + "," +
        $vm.InstanceSize + "," +
        $vm.VirtualNetworkName
     }
    ""

    "** List of Endpoints by VMs **"
    Get-AzureVM -OutVariable vms >$null
    foreach ($vm in $vms) {
        $vm.ServiceName + "," + $vm.Name
        "--------------------------------------"
        Get-AzureVM -Name $vm.Name  -ServiceName $vm.ServiceName |Get-AzureEndpoint |FT
     }
    ""

    "** List of Networks **"
    Get-AzureVirtualNetwork |FT

    "** List of Traffic Manager Profiles **"
    Get-AzureTrafficManagerProfile

    "** List of DNS **"
    Get-AzureDNS

    "** List of Non-Public VM Images **"
    Get-AzureVMImage | where-object { $_.Category -ne "Public"}  -OutVariable images >$null
    "Image Name,OS,Service Name,Role Name,Location"
    foreach ($image in $images) {
        $image.ImageName + "," +
        $image.OS + ","  +
        $image.ServiceName + ","  +
        $image.RoleName + "," +
        $image.Location
     }


    "** List of Azure Disks **"
    Get-AzureDisk -OutVariable disks >$null
    "Disk Name,Disk Size(GB),IO Type,OS,Location"
    foreach ($disk in $disks) {
        $disk.DiskName + "," +
        $disk.DiskSizeInGB + ","  +
        $disk.IOType + ","  +
        $disk.OS + "," +
        $disk.Location
     }

    #Other
    #Get-AzureAffinityGroup 
    #Get-AzureDeployment
}



#### Functions

# Credits : http://blog.kloud.com.au/2014/11/11/get-azure-virtual-networks-with-powershell/
function Get-AzureVirtualNetwork {            
        
    #Get the current Network Config
    $XML = Get-AzureVNetConfig 
    #Define it as XML
    [ xml ]$fileContents = $XML.XMLConfiguration


    #Get to the root of the Network Configuration
    $networks = $fileContents.DocumentElement.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite
    #How Many Sites?
    $SiteCount = ($fileContents.DocumentElement.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite.Name).Count
    # Start the count at 0 so we can work through the multi-dimensional arrays
    $Count = 0

    if($SiteCount -eq 1) {
        $Site = @()
        While($Count -le $SiteCount -and $Count -ne $SiteCount) {
            #Start Site
            $Object = New-Object System.Object

            #Get The Network Site Name & Location - Static amoungst whole network site
            $Object | Add-Member -type NoteProperty -name "Name" -Value $Networks.Name
            $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks.Location
            $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks.Name
            $Object | Add-Member -Type NoteProperty -name "Type" -Value "Site"
            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $Networks.addressspace.AddressPrefix
            $Site += $Object
            
            #Get All the Subnets in the Network
            $SubnetCount = ($Networks.subnets.subnet.name).count
            if($SubnetCount -gt 0) {
                $SubNetCounts = 0
                while($SubnetCounts -le $SubnetCount -and $SubnetCounts -ne $SubnetCount) {
                    $Object = New-Object System.Object

                    if($SubNetCounts -eq 0) {
                        $SubnetNamesCount = ($networks.subnets.Subnet.name).count
                        if($SubnetNamesCount -gt 1) {
                            $Object | Add-Member -type NoteProperty -name "Name" -Value $networks.subnets.Subnet.name[0]
                        }
                        else {
                            $Object | Add-Member -type NoteProperty -name "Name" -Value $networks.subnets.Subnet.name
                        }
                        $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks.Name
                        $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks.Location
                        $Object | Add-Member -Type NoteProperty -name "Type" -Value "Subnet"
                            
                        $PrefixCount = ($networks.subnets.Subnet.AddressPrefix).count
                        if($PrefixCount -gt 1) {
                            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks.subnets.Subnet.AddressPrefix[0]
                        }
                        else {
                            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks.subnets.Subnet.AddressPrefix
                        }

                    }
                    else {
                        $Object | Add-Member -type NoteProperty -name "Name" -Value $networks.subnets.Subnet.name[$SubNetCounts]
                        $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks.Name
                        $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks.Location
                        $Object | Add-Member -Type NoteProperty -name "Type" -Value "Subnet"
                        $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks.subnets.Subnet.AddressPrefix[$SubNetCounts]
                    }

                    $Site += $Object
                    $SubNetCounts++
                }
            }
            $Count++
        }    
    }
    if($SiteCount -gt 1) {
        $Site = @()
        While($Count -le $SiteCount -and $Count -ne $SiteCount) {
            #Start Site
            $Object = New-Object System.Object

            #Get The Network Site Name & Location - Static amoungst whole network site
            $Object | Add-Member -type NoteProperty -name "Name" -Value $Networks[$count].Name
            $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks[$count].Location
            $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks[$count].Name
            $Object | Add-Member -Type NoteProperty -name "Type" -Value "Site"
            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $Networks[$count].addressspace.AddressPrefix
            $Site += $Object

            #Get All the Subnets in the Network
            $SubnetCount = ($Networks[$count].subnets.subnet.name).count
            if($SubnetCount -gt 0) {
                $SubNetCounts = 0
                while($SubnetCounts -le $SubnetCount -and $SubnetCounts -ne $SubnetCount) {
                    $Object = New-Object System.Object

                    if($SubNetCounts -eq 0) {
                        $SubnetNamesCount = ($networks[$count].subnets.Subnet.name).count
                        if($SubnetNamesCount -gt 1) {
                            $Object | Add-Member -type NoteProperty -name "Name" -Value $networks[$count].subnets.Subnet.name[0]
                        }
                        else {
                            $Object | Add-Member -type NoteProperty -name "Name" -Value $networks[$count].subnets.Subnet.name
                        }
                        $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks[$count].Name
                        $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks[$count].Location
                        $Object | Add-Member -Type NoteProperty -name "Type" -Value "Subnet"
                            
                        $PrefixCount = ($networks[$count].subnets.Subnet.AddressPrefix).count
                        if($PrefixCount -gt 1) {
                            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks[$count].subnets.Subnet.AddressPrefix[0]
                        }
                        else {
                            $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks[$count].subnets.Subnet.AddressPrefix
                        }

                    }
                    else {
                        $Object | Add-Member -type NoteProperty -name "Name" -Value $networks[$count].subnets.Subnet.name[$SubNetCounts]
                        $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks[$count].Name
                        $Object | Add-Member -type NoteProperty -name "Location" -Value $Networks[$count].Location
                        $Object | Add-Member -Type NoteProperty -name "Type" -Value "Subnet"
                        $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $networks[$count].subnets.Subnet.AddressPrefix[$SubNetCounts]
                    }
                    $Site += $Object
                    $SubNetCounts++
                }
            }
        $Count++
        }
    }
$Site 
}


function Get-AzureVirtualNetworkRoutes {
    #Get the current Network Config
    $XML = Get-AzureVNetConfig 
    #Define it as XML
    [ xml ]$fileContents = $XML.XMLConfiguration 
    #Get the current Local Network  Config
    $networks = $fileContents.DocumentElement.VirtualNetworkConfiguration.LocalNetworkSites.LocalNetworkSite
    #How Many Sites
    $SiteCount = ($fileContents.DocumentElement.VirtualNetworkConfiguration.LocalNetworkSites.LocalNetworkSite.Name).Count
    $Count = 0

    if($SiteCount -eq 1) {
        $LocalSite = @()
        While($Count -le $SiteCount -and $Count -ne $SiteCount) {
            #Get All the Subnets in the Network
            $SubnetCount = ($Networks.AddressSpace.AddressPrefix).count
            if($SubnetCount -gt 0) {
                    $SubNetCounts = 0
                    while($SubnetCounts -le $SubnetCount -and $SubnetCounts -ne $SubnetCount) {
                        $Object = New-Object System.Object
                        $Object | Add-Member -Type NoteProperty -name "Network" -Value $Networks.Name
                        $object | Add-Member -Type NoteProperty -name "AddressPrefix" -value $Networks.AddressSpace.AddressPrefix[$SubNetCounts]
                        $LocalSite += $Object
                        $SubNetCounts++
                    }
                }
        $Count++
        }
    }
    $LocalSite
}
