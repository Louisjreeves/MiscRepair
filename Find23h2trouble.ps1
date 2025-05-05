# ========================================
# Azure Stack HCI Orchestration + ARC Update Diagnostic Script
# ========================================
Write-Host "`n🔍 Gathering Azure Stack HCI Update Services, Processes, and Cluster Resources..." -ForegroundColor Cyan

# 1. SERVICES
$serviceFilter = @(
    '*AzureStack Agent Lifecycle Agent*',
    '*AzureStack UpdateService*',
    '*AzureStack HciOrchestratorService*',
    '*AzureStack File Copy Agent*',
    '*AzureStack Firewall Agent*',
    '*AzureStack Arc Extension Observability Agent*',
    '*AzureStack SyslogForwarder Agent*',
    '*AzureStack Trace Collector Agent*'
)

$services = Get-Service | Where-Object {
    foreach ($pattern in $serviceFilter) {
        if ($_.DisplayName -like $pattern) { return $true }
    }
}

Write-Host "`n🧩#1  Relevant Azure Stack Services:" -ForegroundColor Yellow
$services | Sort-Object DisplayName | Format-Table Status, Name, DisplayName

# 2. PROCESSES
$processFilter = @(
    '*EnterpriseCloudEngine*',
    '*HciOrchestrator*',
    '*AzureStack.UpdateService*',
    '*AzureStack.Solution.Deploy*',
    '*AzureStack.Download.Monitor*',
    '*AzureStack.Infrastructure.Health*'
)

$processes = Get-Process | Where-Object {
    foreach ($pattern in $processFilter) {
        if ($_.Name -like $pattern) { return $true }
    }
}

Write-Host "`n🧠 #2 Active Update and Agent Processes:" -ForegroundColor Yellow
$processes | Select-Object Id, ProcessName, CPU, StartTime | Format-Table -AutoSize

# 3. CLUSTER RESOURCES
if (Get-Command Get-ClusterResource -ErrorAction SilentlyContinue) {
    Write-Host "`n🔗 #3 Cluster Resources (if any):" -ForegroundColor Yellow
    Get-ClusterResource | Where-Object {
        $_.Name -match 'Agent|Extension|Update|Arc|HCI|Orchestrator'
    } | Format-Table Name, ResourceType, OwnerNode, State
} else {
    Write-Host "`n[!] Not in a cluster context or Failover-Clustering module not available." -ForegroundColor Red
}

# 4. CURRENT SOLUTION UPDATES
Write-Host "`n📦 #4 Current Solution Updates in system:" -ForegroundColor Yellow
Get-SolutionUpdate | Format-List ResourceId, State, Component, PackageType

# Filter to updates that are not installed
$currenttodo = Get-SolutionUpdate | Where-Object { $_.State -ne "Installed" }

 Write-Host "`n📋 #4.5  Current todo failed items :" -ForegroundColor Yellow
 $currenttodo | fl


# 5. LIST OF FAILED SOLUTION UPDATE RUNS
$failure = $currenttodo | Get-SolutionUpdateRun

if ($failure) {
    Write-Host "`n📋 #5 List of Action Plan Resource IDs:" -ForegroundColor Yellow
    $failure.ResourceId | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }

    # Ask user to enter a Resource ID
    $variablehere = Read-Host "`nEnter the ResourceId you want to lookup (copy from list above)"

    # Confirm choice
    Write-Host "`nYou selected ResourceId: $variablehere" -ForegroundColor Green

    # Run Get-ActionPlanInstance against selected ResourceId
   # Get-ActionPlanInstance -ActionPlanInstanceId $variablehere
   $TimeStamp = get-date -Format "yyMMdd_hhmmss"
 $OutputFile = "c:\Update_10.2311.2.7_Fail_" + $TimeStamp + ".xml"
  (Get-ActionplanInstance -ActionplanInstanceId $variablehere).ProgressAsXml | Out-file -FilePath $OutputFile
  Write-host "In the root of c you will find the ECE output and hopefully the problem!"
} else {
    Write-Host "`n✔️ No failed Solution Update Runs found." -ForegroundColor Green
}

Write-Host "`n✅ Done. Review services, processes, updates, and action plans as needed." -ForegroundColor Green


# 6. CLUSTER RESOURCE CHECKS: ClusterAwareUpdatingResource and Distributed Network Name
$readme = read-host "do you want to put the ActionplaninstanceID in again to get the output to this screen? y/n "
if($readme -like "y"){Write-host "Will output the results ad the end of this program run"}

Write-Host "`n🔍#6  Checking ClusterAwareUpdatingResource status:" -ForegroundColor Yellow
$cluaware = Get-ClusterResource | Where-Object { $_.ResourceType -eq "ClusterAwareUpdatingResource" }

if ($cluaware) {
    $cluaware | Format-Table Name, State, OwnerNode
} else {
    Write-Host "⚠️ No ClusterAwareUpdatingResource found." -ForegroundColor DarkYellow
}

Write-Host "`n🔍 #6.5 Checking Distributed Network Name resources:" -ForegroundColor Yellow
$distname = Get-ClusterResource | Where-Object { $_.ResourceType -eq "Distributed Network Name" }

if ($distname) {
    $distname | Format-Table Name, State, OwnerNode
} else {
    Write-Host "⚠️ No Distributed Network Name resources found." -ForegroundColor DarkYellow
}


#7 Get-mocconfig

 

Write-Host "`n🔍#7  Checking MOC CONFIG- MOC and ARB use these settings:" -ForegroundColor Yellow
$mymoc = get-mocconfig

if ($mymoc) {
    $mymoc | Format-Table  
} else {
    Write-Host "⚠️ No ClusterAwareUpdatingResource found." -ForegroundColor DarkYellow
}

 
#8  Checks the CAU cluster role to see if its got a job running 
 

Write-Host "`n🔍#8  Checking CAU Role- This is run by SDP Service Delivery Platform:" -ForegroundColor Yellow
$mycauc = Get-CauCLusterRole

if ($mycauc) {
    $mycauc | Format-Table  
} else {
    Write-Host "⚠️ No cau role found." -ForegroundColor DarkYellow
}

#10 get-caurun
Write-Host "`n🔍#8  Checking CAU running or not- This is run by SDP Service Delivery Platform:" -ForegroundColor Yellow
$mycaurun = Get-Caurun

if ($mycaurun) {
   $mycaurun| Format-Table  
} else {
    Write-Host "⚠️ No Caurun found." -ForegroundColor DarkYellow
}



#9 FOr a Person who is stuck and truly doesnt know what to do- dont worry 
# Take a deep breath and #1 try to match the issue to one of the situations here

#https://github.com/Azure/AzureLocal-Supportability/tree/main

# if that doesnt work, get a second pair of eyes. it cant hurt but may be of help. 

# 9. FINAL ADVICE FOR TROUBLESHOOTING

Write-Host "`n🧘 FINAL TIP:#9  If you're stuck and unsure what to do..." -ForegroundColor Cyan

Write-Host "`n#1 Take a deep breath. You're doing fine." -ForegroundColor Yellow
Write-Host "#2 Try to match your issue to one of the common supportability situations listed here:" -ForegroundColor Yellow
Write-Host "   https://github.com/Azure/AzureLocal-Supportability/tree/main" -ForegroundColor Blue
Write-Host "#3 If that doesn't solve it, get a second pair of eyes. A fresh perspective can make all the difference." -ForegroundColor Yellow

Write-Host "`n💬 You're not alone. Most issues have a solution — and you're already halfway there by investigating this carefully!" -ForegroundColor Green

if ($readme -like "y") {
    $command = "Start-MonitoringActionplanInstanceToComplete -actionPlanInstanceID '$variablehere'"
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $command
}

 






