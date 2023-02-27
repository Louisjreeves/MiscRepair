
Function Get-CacheDiskStatus 
{
<#
	.DESCRIPTION
    
		Get-CacheDiskStatus is a script that can be used verify the boundings to cache devices
        with Storage Spaces Direct
                
	.INPUTS
 
		None
 
	.OUTPUTS
 
		None
 
	.NOTES
 
		Author: Darryl van der Peijl
		Website: http://www.DarrylvanderPeijl.nl/
		Email: DarrylvanderPeijl@outlook.com
		Date created: 3.january.2018
		Last modified: 04.October.2019
        Last modified by: Ben Thomas (@NZ_BenThomas)
		Version: 1.2

 
	.LINK
    
		http://www.DarrylvanderPeijl.nl/
		https://twitter.com/DarrylvdPeijl
#>
Param (
        [parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClusterName
)


function Get-PCStorageReportSSBCache ()
{
    BEGIN {
            $csvf = New-TemporaryFile

            function Format-SSBCacheDiskState
            ([string] $DiskState)
                {
                    $DiskState -replace 'CacheDiskState',''
                }
            function Format-SSBDiskID{
                param(
                    $Disk
                )
                "$($Disk.FriendlyName) - $($Disk.SerialNumber)"
            }
    }

    <#
    These are the possible DiskStates
    typedef enum
    {
        CacheDiskStateUnknown                   = 0,
        CacheDiskStateConfiguring               = 1,
        CacheDiskStateInitialized               = 2,
        CacheDiskStateInitializedAndBound       = 3,     <- expected normal operational
        CacheDiskStateDraining                  = 4,     <- expected during RW->RO change (waiting for dirty pages -> 0)
        CacheDiskStateDisabling                 = 5,
        CacheDiskStateDisabled                  = 6,     <- expected post-disable of S2D
        CacheDiskStateMissing                   = 7,
        CacheDiskStateOrphanedWaiting           = 8,
        CacheDiskStateOrphanedRecovering        = 9,
        CacheDiskStateFailedMediaError          = 10,
        CacheDiskStateFailedProvisioning        = 11,
        CacheDiskStateReset                     = 12,
        CacheDiskStateRepairing                 = 13,
        CacheDiskStateIneligibleDataPartition   = 2000,
        CacheDiskStateIneligibleNotGPT          = 2001,
        CacheDiskStateIneligibleNotEnoughSpace  = 2002,
        CacheDiskStateIneligibleUnsupportedSystem = 2003,
        CacheDiskStateIneligibleExcludedFromS2D = 2004,
        CacheDiskStateIneligibleForS2D          = 2999,
        CacheDiskStateSkippedBindingNoFlash     = 3000,
        CacheDiskStateIgnored                   = 3001,
        CacheDiskStateNonHybrid                 = 3002,
        CacheDiskStateInternalErrorConfiguring  = 9000,
        CacheDiskStateMarkedBad                 = 9001,
        CacheDiskStateMarkedMissing             = 9002,
        CacheDiskStateInStorageMaintenance      = 9003   <- expected during FRU/maint
    }
    CacheDiskState;
    #>

    PROCESS {

            $log = get-clusterlog -Node $env:computername -Destination C:\Clusterlog -TimeSpan 1
            dir C:\clusterlog\*cluster.log | sort -Property BaseName |% {
            $node = "<unknown>"
            if ($_.BaseName -match "^(.*)_cluster$") {
                $node = $matches[1]
            }

            Write-Output ("-"*40) "Node: $node"
            $PhysicalDisks = Get-StorageSubSystem clu* | Get-StorageNode |?{$_.Name -ilike "$node.*"} | Get-PhysicalDisk -PhysicallyConnected


            ##
            # Parse cluster log for the SBL Disk section
            ## 

            $sr = [System.IO.StreamReader]$_.FullName

            $in = $false
            $parse = $false
            $(do {
                $l = $sr.ReadLine()
        
                # Heuristic ...
                # SBL Disks comes before System

                if ($in) {
                    # in section, blank line terminates
                    if ($l -notmatch '^\s*$') {
                        $l
                    } else {
                        # parse was good
                        $parse = $true
                        break
                    }
                } elseif ($l -match '^\[=== SBL Disks') {
                    $in = $true
                } elseif ($l -match '^\[=== System') {
                    break
                }
        
            } while (-not $sr.EndOfStream)) > $csvf

            ##
            # With a good parse, provide commentary
            ##

            if ($parse) {
                $d = import-csv $csvf

                ##
                # Table of raw data, friendly cache device numbering
                ##

                $idmap = @{}
                $d |% {
                    $idmap[$_.DiskId] = $_.DeviceNumber
                }

                
                $d | sort IsSblCacheDevice,CacheDeviceId,DiskState | ft -AutoSize @{ Label = 'DiskState'; Expression = { Format-SSBCacheDiskState $_.DiskState }},
                    @{ Label = 'DiskName'; Expression = { $Disk = $_.DiskID; Format-SSBDiskID -Disk ($PhysicalDisks | ?{$_.ObjectID -imatch $Disk}) } },
                    DeviceNumber,@{
                    Label = 'CacheDeviceNumber'; Expression = {
                        if ($_.IsSblCacheDevice -eq 'true') {
                            '= cache'
                        } elseif ($idmap.ContainsKey($_.CacheDeviceId)) {
                            $idmap[$_.CacheDeviceId]
                        } elseif ($_.CacheDeviceId -eq '{00000000-0000-0000-0000-000000000000}') {
                            "= unbound"
                        } else {
                            # should be DiskStateMissing or OrphanedWaiting? Check live.
                            "= not present $($_.CacheDeviceId)"
                        }
                    }
                },HasSeekPenalty,PathId,BindingAttributes,DirtyPages
                

                ##
                # Now do basic testing of device counts
                ##

                $dcache = $d |? IsSblCacheDevice -eq 'true'
                $dcap = $d |? IsSblCacheDevice -ne 'true'

                Write-Output "Device counts: cache $($dcache.count) capacity $($dcap.count)"
        
                ##
                # Test cache bindings if we do have cache present
                ##

                if ($dcache) {

                    # first uneven check, the basic count case
                    $uneven = $false
                    if ($dcap.count % $dcache.count) {
                        $uneven = $true
                        Write-Warning "Capacity device count does not evenly distribute to cache devices"
                    }

                    # now look for unbound devices
                    $unbound = $dcap |? CacheDeviceId -eq '{00000000-0000-0000-0000-000000000000}'
                    if ($unbound) {
                        Write-Warning "There are $(@($unbound).count) unbound capacity device(s)"
                    }

                    # unbound devices give us the second uneven case
                    if (-not $uneven -and ($dcap.count - @($unbound).count) % $dcache.count) {
                        $uneven = $true
                    }

                    $gdev = $dcap |? DiskState -eq 'CacheDiskStateInitializedAndBound' | group -property CacheDeviceId

                    if (@($gdev).count -ne $dcache.count) {
                        Write-Warning "Not all cache devices in use"
                    }

                    $gdist = $gdev |% { $_.count } | group

                    # in any given round robin binding of devices, there should be at most two counts; n and n-1

                    # single ratio
                    if (@($gdist).count -eq 1) {
                        Write-Output "Binding ratio is even: 1:$($gdist.name)"
                    } else {
                        # group names are n in the 1:n binding ratios
                        $delta = [math]::Abs([int]$gdist[0].name - [int]$gdist[1].name)

                        if ($delta -eq 1 -and $uneven) {
                            Write-Output "Binding ratios are as expected for uneven device ratios"
                        } else {
                            Write-Warning "Binding ratios are uneven"
                        }

                        # form list of group sizes
                        $s = $($gdist |% {
                            "1:$($_.name) ($($_.count) total)"
                        }) -join ", "

                        Write-Output "Groups: $s"
                    }
                }

                ##
                # Provide summary of diskstate if more than one is present in the results
                ##

                $g = $d | group -property DiskState

                if (@($g).count -ne 1) {
                    write-output "Disk State Summary:"
                    $g | sort -property Name | ft @{ Label = 'DiskState'; Expression = { Format-SSBCacheDiskState $_.Name}},@{ Label = "Number of Disks"; Expression = { $_.Count }}
                } else {
                    $gname = (($g.name) -replace 'CacheDiskState','')
                    write-output "All disks are in $gname"
                }
            }
        }
    }

    END {

        del $csvf
    }
}




    Get-clusternode -Cluster $ClusterName | % {
    
        Invoke-Command -ComputerName $_.NodeName -ScriptBlock ${Function:Get-PCStorageReportSSBCache}
    
    }

}
