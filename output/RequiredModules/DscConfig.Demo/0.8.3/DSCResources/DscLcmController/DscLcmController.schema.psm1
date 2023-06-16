$dscLcmControllerScript = @'
function Get-DscConfigurationVersionLocal {

    $hash = @{}
    $key = Get-Item HKLM:\SOFTWARE\DscTagging -ErrorAction SilentlyContinue

    if( $null -ne $key ) {
        foreach ($property in $key.Property) {
            $hash.Add($property, $key.GetValue($property))
        }
    }
    else {
        $hash.Version = 'Unknown'
    }

    New-Object -TypeName PSObject -Property $hash
}

function Send-DscTaggingData {
    [CmdletBinding()]
    param()

    $pattern = 'http[s]?:\/\/(?<PullServer>([^\/:\.[:space:]]+(\.[^\/:\.[:space:]]+)*)|([0-9](\.[0-9]{3})))(:[0-9]+)?((\/[^?#[:space:]]+)(\?[^#[:space:]]+)?(\#.+)?)?'
    try {
        $lcm = Get-DscLocalConfigurationManager -ErrorAction Stop
        $pullServerUrl = $lcm.ConfigurationDownloadManagers.ServerURL
        $agentId = $lcm.AgentId

        Write-Host "PullServerUrl = '$pullServerUrl'"
        Write-Host "AgentId = '$agentId'"

        $found = $pullServerUrl -match $pattern

        if (-not $found) {
            Write-Error "Could not find pull server in Url '$pullServerUrl'" -ErrorAction Stop
        }
    }
    catch {
        Write-Error "Cannot get pull server name from 'Get-DscLocalConfigurationManager' output, the error was $($_.Exception.Message)"
        return
    }

    $versionData = Get-DscConfigurationVersionLocal

    if ($versionData.Layers.Count -gt 1) {
        $versionData.Layers = $versionData.Layers -join ', '
    }

    Write-Host
    Write-Host "Sending the following DSC version data to JEA endpoint on pull server '$($Matches.PullServer)'"
    $versionData | Out-String | Write-Host

    Invoke-Command -ComputerName $Matches.PullServer -ConfigurationName DscData -ScriptBlock {
        Send-DscTaggingData -AgentId $args[0] -Data $args[1]
    } -ArgumentList $agentId, $versionData
}

function Set-LcmPostpone {
    $postponeInterval = 14
    if ($lastLcmPostpone.AddDays($postponeInterval) -gt (Get-Date)) {
        Write-Host "Last LCM postpone was done at '$lastLcmPostpone'. Next one will not be triggered before '$($lastLcmPostpone.AddDays($postponeInterval))'"
        Write-Host
        return
    }
    else {
        Write-Host "Last LCM postpone was done at '$lastLcmPostpone'. Triggering LCM postone as the last time was more than $postponeInterval ago"
        Write-Host
    }

    $currentLcmSettings = Get-DscLocalConfigurationManager
    $maxConsistencyCheckInterval = if ($currentLcmSettings.ConfigurationModeFrequencyMins -eq 44640) {
        44639 #value must be changed in order to reset the LCM timer
    }
    else {
        44640 #minutes for 31 days
    }

    $maxRefreshInterval = if ($currentLcmSettings.RefreshFrequencyMins -eq 44640) {
        44639 #value must be changed in order to reset the LCM timer
    }
    else {
        44640 #minutes for 31 days
    }

    $metaMofFolder = mkdir -Path "$path\MetaMof" -Force

    if (Test-Path -Path C:\Windows\System32\Configuration\MetaConfig.mof) {
        $mofFile = Copy-Item -Path C:\Windows\System32\Configuration\MetaConfig.mof -Destination "$path\MetaMof\localhost.meta.mof" -Force -PassThru
    }
    else {
        $mofFile = Get-Item -Path "$path\MetaMof\localhost.meta.mof" -ErrorAction Stop
    }
    $content = Get-Content -Path $mofFile.FullName -Raw -Encoding Unicode

    $pattern = '(ConfigurationModeFrequencyMins(\s+)?=(\s+)?)(\d+)(;)'
    $content = $content -replace $pattern, ('$1 {0}$5' -f $maxConsistencyCheckInterval)

    $pattern = '(RefreshFrequencyMins(\s+)?=(\s+)?)(\d+)(;)'
    $content = $content -replace $pattern, ('$1 {0}$5' -f $maxRefreshInterval)

    $content | Out-File -FilePath $mofFile.FullName -Encoding unicode

    Set-DscLocalConfigurationManager -Path $metaMofFolder

    "$(Get-Date) - Postponed LCM" | Add-Content -Path "$path\LcmPostponeSummary.log"

    Set-ItemProperty -Path $dscLcmController.PSPath -Name LastLcmPostpone -Value (Get-Date) -Type String -Force
}

function Test-InMaintenanceWindow {
    if ($maintenanceWindows) {
        $inMaintenanceWindow = foreach ($maintenanceWindow in $maintenanceWindows) {
            Write-Host "Reading maintenance window '$($maintenanceWindow.PSChildName)'"
            [datetime]$startTime = Get-ItemPropertyValue -Path $maintenanceWindow.PSPath -Name StartTime
            [timespan]$timespan = Get-ItemPropertyValue -Path $maintenanceWindow.PSPath -Name Timespan
            [datetime]$endTime = $startTime + $timespan
            [string]$dayOfWeek = try {
                Get-ItemPropertyValue -Path $maintenanceWindow.PSPath -Name DayOfWeek
            }
            catch { }
            [string]$on = try {
                Get-ItemPropertyValue -Path $maintenanceWindow.PSPath -Name On
            }
            catch { }

            if ($dayOfWeek) {
                if ((Get-Date).DayOfWeek -ne $dayOfWeek) {
                    Write-Host "DayOfWeek is set to '$dayOfWeek'. Current day of week is '$((Get-Date).DayOfWeek)', maintenance window does not apply"
                    continue
                }
                else {
                    Write-Host "Maintenance Window is configured for week day '$dayOfWeek' which is the current day of week."
                }
            }

            if ($on) {

                if ($on -ne 'last') {
                    $on = [int][string]$on[0]
                }

                $daysInMonth = [datetime]::DaysInMonth($now.Year, $now.Month)
                $daysInMonth = for ($i = 1; $i -le $daysInMonth; $i++) {
                    Get-Date -Date $now -Day $i
                }

                $daysInMonth = $daysInMonth | Where-Object { $_.DayOfWeek -eq $dayOfWeek }

                $daysInMonth = if ($on -eq 'last') {
                    $daysInMonth | Select-Object -Last 1
                }
                else {
                    $daysInMonth | Select-Object -Index ($on - 1)
                }

                if ($daysInMonth.ToShortDateString() -ne $now.ToShortDateString()) {
                    Write-Host "Today is not the '$on' $dayOfWeek in the current month"
                    continue
                }
                else {
                    Write-Host "The LCM is supposed to run on the '$on' $dayOfWeek which applies to today"
                }
            }

            Write-Host "Maintenance window: $($startTime) - $($endTime)."
            if ($currentTime -gt $startTime -and $currentTime -lt $endTime) {
                Write-Host "Current time '$currentTime' is in maintenance window '$($maintenanceWindow.PSChildName)'"

                Write-Host "IN MAINTENANCE WINDOW: Setting 'inMaintenanceWindow' to 'true' as the current time is in a maintanence windows."
                $true
                break
            }
            else {
                Write-Host "Current time '$currentTime' is not in maintenance window '$($maintenanceWindow.PSChildName)'"
            }
        }
    }
    else {
        Write-Host "No maintenance windows defined. Setting 'inMaintenanceWindow' to 'false'."
        $false
    }
    Write-Host

    if (-not $inMaintenanceWindow -and $maintenanceWindowOverride) {
        Write-Host "OVERRIDE: 'inMaintenanceWindow' is 'false' but 'maintenanceWindowOverride' is enabled, setting 'inMaintenanceWindow' to 'true'"
        $true
    }
    elseif (-not $inMaintenanceWindow) {
        Write-Host "NOT IN MAINTENANCE WINDOW: 'inMaintenanceWindow' is 'false'. The current time is not in any of the $($maintenanceWindows.Count) maintenance windows."
        $false
    }
    else {
        $inMaintenanceWindow
    }
}

function Set-LcmMode {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ApplyAndAutoCorrect', 'ApplyAndMonitor')]
        [string]$Mode
    )
    $metaMofFolder = mkdir -Path "$path\MetaMof" -Force

    if (Test-Path -Path C:\Windows\System32\Configuration\MetaConfig.mof) {
        $mofFile = Copy-Item -Path C:\Windows\System32\Configuration\MetaConfig.mof -Destination "$path\MetaMof\localhost.meta.mof" -Force -PassThru
    }
    else {
        $mofFile = Get-Item -Path "$path\MetaMof\localhost.meta.mof" -ErrorAction Stop
    }
    $content = Get-Content -Path $mofFile.FullName -Raw -Encoding Unicode

    $pattern = '(ConfigurationMode(\s+)?=(\s+)?)("\w+")(;)'
    $content = $content -replace $pattern, ('$1 "{0}"$5' -f $Mode)
    Write-Host "LCM put into '$Mode' mode"
}

function Set-LcmRebootNodeIfNeededMode {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $RebootNodeIfNeeded
    )
    $metaMofFolder = mkdir -Path "$path\MetaMof" -Force
    if (Test-Path -Path C:\Windows\System32\Configuration\MetaConfig.mof)
    {
        $mofFile = Copy-Item -Path C:\Windows\System32\Configuration\MetaConfig.mof -Destination "$path\MetaMof\localhost.meta.mof" -Force -PassThru
    }
    else
    {
        $mofFile = Get-Item -Path "$path\MetaMof\localhost.meta.mof" -ErrorAction Stop
    }
    $content = Get-Content -Path $mofFile.FullName -Raw -Encoding Unicode

    $patternRebootNodeIfNeeded = '(RebootNodeIfNeeded(\s+)?=(\s+)?)(true|false);'
    $content = $content -replace $patternRebootNodeIfNeeded, ('$1 {0};' -f $RebootNodeIfNeeded)
    $content | Out-File -FilePath $mofFile.FullName -Encoding unicode
    Set-DscLocalConfigurationManager -Path $metaMofFolder
    Write-Host "LCM RebootIfNeededValue is set to '$RebootNodeIfNeeded'"
}
function Test-StartDscAutoCorrect {
    if ($maintenanceWindowMode -eq 'AutoCorrect') {

        $nextAutoCorrect = $lastAutoCorrect + $autoCorrectInterval
        Write-Host ""
        Write-Host "The previous AutoCorrect was done on '$lastAutoCorrect', the next one will not be triggered before '$nextAutoCorrect'. AutoCorrectInterval is $autoCorrectInterval."
        if ($currentTime -gt $nextAutoCorrect) {
            Write-Host 'It is time to trigger an AutoCorrect per the defined interval.'
            $doAutoCorrect = $true
        }
        else {
            if ($autoCorrectIntervalOverride) {
                Write-Host "OVERRIDE: It is NOT time to trigger an AutoCorrect per the defined interval but 'AutoCorrectIntervalOverride' is enabled."
                $doAutoCorrect = $true
            }
            else {
                Write-Host 'It is NOT time to trigger an AutoCorrect per the defined interval.'
                $doAutoCorrect = $false
            }
        }
        $doAutoCorrect
    }
    else {
        $false
    }

}

function Test-StartDscRefresh {
    if ($maintenanceWindowMode -eq 'AutoCorrect') {

        $nextRefresh = $lastRefresh + $refreshInterval
        Write-Host ""
        Write-Host "The previous Refresh was done on '$lastRefresh', the next one will not be triggered before '$nextRefresh'. RefreshInterval is $refreshInterval."
        if ($currentTime -gt $nextRefresh) {
            Write-Host 'It is time to trigger a Refresh per the defined interval.'
            $doRefresh = $true
        }
        else {
            if ($refreshIntervalOverride) {
                Write-Host "OVERRIDE: It is NOT time to trigger a Refresh check per the defined interval but 'refreshIntervalOverride' is enabled."
                $doRefresh = $true
            }
            else {
                Write-Host 'It is NOT time to trigger a Refresh check per the defined interval.'
                $doRefresh = $false
            }
        }
        $doRefresh
    }
    else {
        $false
    }

}

function Start-AutoCorrect {
    Write-Host "ACTION: Invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags '1' (Consistency Check)."
    try {
        $script:lcmRuntime = Start-LcmRequiredConfigurationChecks -Mode AutoCorrect -MaxLcmRuntime $maxLcmRuntime -Flags 1
        $dscLcmController = Get-Item -Path HKLM:\SOFTWARE\DscLcmController
        Set-ItemProperty -Path $dscLcmController.PSPath -Name LastAutoCorrect -Value (Get-Date) -Type String -Force
    }
    catch {
        Write-Error "Error invoking 'PerformRequiredConfigurationChecks'. The message is: '$($_.Exception.Message)'"
        $script:autoCorrectErrors = $true
    }
}

function Start-Monitor {
    Write-Host "ACTION: Invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags '1' (Consistency Check)."
    try {
        $script:lcmRuntime = Start-LcmRequiredConfigurationChecks -Mode Monitor -MaxLcmRuntime $maxLcmRuntime -Flags 1
        $dscLcmController = Get-Item -Path HKLM:\SOFTWARE\DscLcmController
        Set-ItemProperty -Path $dscLcmController.PSPath -Name LastMonitor -Value (Get-Date) -Type String -Force
    }
    catch {
        Write-Error "Error invoking 'PerformRequiredConfigurationChecks'. The message is: '$($_.Exception.Message)'"
        $script:monitorErrors = $true
    }
}

function Start-Refresh {
    Write-Host "ACTION: Invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags'5' (Pull and Consistency Check)."
    try {
        $script:lcmRuntime = Start-LcmRequiredConfigurationChecks -Mode AutoCorrect -MaxLcmRuntime $maxLcmRuntime -Flags 5
        $dscLcmController = Get-Item -Path HKLM:\SOFTWARE\DscLcmController
        Set-ItemProperty -Path $dscLcmController.PSPath -Name LastRefresh -Value (Get-Date) -Type String -Force
        if ($sendDscTaggingData) {
            try {
                Send-DscTaggingData -ErrorAction Stop
            }
            catch {
                $sendDscTaggingDataError = $true
            }
        }
    }
    catch {
        Write-Error "Error invoking 'PerformRequiredConfigurationChecks'. The message is: '$($_.Exception.Message)'"
        $script:refreshErrors = $true
    }
}

function Test-StartDscMonitor {
    $nextMonitor1 = $lastMonitor + $monitorInterval
    $nextMonitor2 = $lastAutoCorrect + $monitorInterval
    $nextMonitor = [datetime][math]::Max($nextMonitor1.Ticks, $nextMonitor2.Ticks)

    Write-Host ''
    Write-Host "The previous Monitor was done on '$lastMonitor', the next one will not be triggered before '$nextMonitor'. MonitorInterval is $monitorInterval."
    if ($currentTime -gt $nextMonitor) {
        Write-Host 'It is time to trigger a Monitor per the defined interval.'
        $doMonitor = $true
    }
    else {
        Write-Host 'It is NOT time to trigger a Monitor per the defined interval.'
        $doMonitor = $false
    }
    $doMonitor
}

function Start-LcmRequiredConfigurationChecks {
    param(
        [OutputType([timespan])]
        [Parameter()]
        [timespan]$MaxLcmRuntime = (New-TimeSpan -Days 2),

        [Parameter(Mandatory = $true)]
        [ValidateSet('Monitor', 'AutoCorrect')]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [int]$Flags
    )
    Write-Verbose "Entering 'Start-LcmRequiredConfigurationChecks'"

    $internalMaxLcmRuntime = $MaxLcmRuntime

    $j = Start-Job -ScriptBlock {
        param(
            [Parameter(Mandatory = $true)]
            [int]$Flags
        )
        $params = @{
            ClassName   = 'MSFT_DSCLocalConfigurationManager'
            Namespace   = 'root/Microsoft/Windows/DesiredStateConfiguration'
            MethodName  = 'PerformRequiredConfigurationChecks'
            Arguments   = @{ Flags = [uint32]$Flags }
            ErrorAction = 'Stop'
        }
        Write-Output "Calling 'Invoke-CimMethod' with the following parameters:"
        $params | ConvertTo-Json | Write-Output
        Invoke-CimMethod @params | Out-Null

    } -ArgumentList $Flags

    Write-Host "Waiting $MaxLcmRuntime for the background job to finish."

    while ($j.State -eq 'Running' -and $internalMaxLcmRuntime -gt 0) {
        $waitIntervalInSeconds = 5
        Start-Sleep -Seconds $waitIntervalInSeconds
        $output = $j | Receive-Job | Out-String
        if ($output) { $output | Write-Host }
        $internalMaxLcmRuntime = $internalMaxLcmRuntime.Subtract((New-TimeSpan -Seconds $waitIntervalInSeconds))
    }

    if ($j.State -eq 'Running') {
        Write-Host "LCM did not finish with the timeout of '$MaxLcmRuntime'"
        $j | Stop-Job
        #find the process that is hosting the DSC engine
        $dscProcess = Get-CimInstance -ClassName  msft_providers | Where-Object { $_.Provider -like 'dsccore' }
        Write-Host "Shutting down LCM process with ID '$($dscProcess.HostProcessIdentifier)'"
        Get-Process -Id $dscProcess.HostProcessIdentifier | Stop-Process -Force
        if ($Mode -eq 'AutoCorrect') {
            Set-ItemProperty -Path $dscLcmController.PSPath -Name LastAutoCorrect -Value (Get-Date -Date 0) -Type String -Force
        }
        else {
            Set-ItemProperty -Path $dscLcmController.PSPath -Name LastMonitor -Value (Get-Date -Date 0) -Type String -Force
        }
        Write-Error -Message "LCM did run longer than '$MaxLcmRuntime'. Process was stopped." -ErrorAction Stop
    }

    $runtime = $j.PSEndTime - $j.PSBeginTime
    Write-Host "LCM runtime was '$runtime'"
    $runtime
}

$writeTranscripts = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name WriteTranscripts
$path = Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath 'Dsc\LcmController'

if ($writeTranscripts) {
    Start-Transcript -Path "$path\LcmController.log" -Append
}

#Disable DSC Timer
$timer = Get-CimInstance -ClassName  msft_providers | Where-Object { $_.Provider -like 'dsctimer' }
$timer | Invoke-CimMethod -MethodName UnLoad

$now = Get-Date
$lcmConfiguration = Get-DscLocalConfigurationManager
$currentConfigurationMode = $lcmConfiguration.ConfigurationMode
$lcmModeChanged = ''
$doConsistencyCheck = $false
$doRefresh = $false
$inMaintenanceWindow = $false
$doAutoCorrect = $false
$doRefresh = $false
$doMonitor = $false
$autoCorrectErrors = $false
$refreshErrors = $false
$monitorErrors = $false
$currentTime = Get-Date
$lcmRuntime = $null
$sendDscTaggingData = $false
$sendDscTaggingDataError = $false
$dscLcmController = Get-Item -Path HKLM:\SOFTWARE\DscLcmController

$maintenanceWindows = Get-ChildItem -Path HKLM:\SOFTWARE\DscLcmController\MaintenanceWindows
[bool]$maintenanceWindowOverride = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name MaintenanceWindowOverride
[timespan]$autoCorrectInterval = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name AutoCorrectInterval
[bool]$autoCorrectIntervalOverride = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name AutoCorrectIntervalOverride
[timespan]$monitorInterval = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name MonitorInterval
[timespan]$refreshInterval = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name RefreshInterval
[bool]$refreshIntervalOverride = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name RefreshIntervalOverride
[timespan]$maxLcmRuntime = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name MaxLcmRuntime
[timespan]$logHistoryTimeSpan = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name LogHistoryTimeSpan
[bool]$sendDscTaggingData = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name SendDscTaggingData
$maintenanceWindowMode = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name MaintenanceWindowMode

[datetime]$lastAutoCorrect = try {
    Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name LastAutoCorrect
}
catch {
    Get-Date -Date 0
}
[datetime]$lastMonitor = try {
    Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name LastMonitor
}
catch {
    Get-Date -Date 0
}
[datetime]$lastRefresh = try {
    Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name LastRefresh
}
catch {
    Get-Date -Date 0
}
[datetime]$lastLcmPostpone = try {
    Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscLcmController -Name LastLcmPostpone
}
catch {
    Get-Date -Date 0
}

Write-Host '----------------------------------------------------------------------------'
Set-LcmPostpone

$inMaintenanceWindow = Test-InMaintenanceWindow
Write-Host
if ($inMaintenanceWindow) {
    if (!$lcmConfiguration.RebootNodeIfNeeded)
    {
        Write-Host "RebootNodeIfNeeded is set to 'False', but it's in maintenance window, set RebootNodeIfNeeded to 'True'"
        Set-LcmRebootNodeIfNeededMode -RebootNodeIfNeeded $true
    }
    if ($maintenanceWindowMode -eq 'AutoCorrect' -and $currentConfigurationMode -ne 'ApplyAndAutoCorrect') {
        Write-Host "MaintenanceWindowMode is '$maintenanceWindowMode' but LCM is set to '$currentConfigurationMode'. Changing LCM to 'ApplyAndAutoCorrect'"
        Set-LcmMode -Mode 'ApplyAndAutoCorrect'
        $lcmModeChanged = 'ApplyAndAutoCorrect'
    }
    elseif ($maintenanceWindowMode -eq 'Monitor' -and $currentConfigurationMode -ne 'ApplyAndMonitor') {
        Write-Host "MaintenanceWindowMode is '$maintenanceWindowMode' but LCM is set to '$currentConfigurationMode'. Changing LCM to 'ApplyAndMonitor'"
        Set-LcmMode -Mode 'ApplyAndMonitor'
        $lcmModeChanged = 'ApplyAndMonitor'
    }
}
else{
    if ($lcmConfiguration.RebootNodeIfNeeded)
    {
        Write-Host "RebootNodeIfNeeded is set to 'True', but it's not into maintenance window, set RebootNodeIfNeeded to 'False'"
        Set-LcmRebootNodeIfNeededMode -RebootNodeIfNeeded $false
    }
}
if ($inMaintenanceWindow) {
    $doAutoCorrect = Test-StartDscAutoCorrect
    $doRefresh = Test-StartDscRefresh

    if ($doRefresh) {
        Start-Refresh
    }
    else {
        Write-Host "NO ACTION: 'doRefresh' is false, not invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags '5' (Pull and Consistency Check)."
    }

    if ($doAutoCorrect) {
        Start-AutoCorrect
    }
    else {
        Write-Host "NO ACTION: 'doAutoCorrect' is false, not invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags '1' (Consistency Check)."
    }

}

Write-Host
if ($lcmModeChanged) {
    Write-Host "Setting LCM back from '$lcmModeChanged' to '$currentConfigurationMode'."
    Set-LcmMode -Mode $currentConfigurationMode
}

Write-Host
if (-not $doAutoCorrect) {
    $doMonitor = Test-StartDscMonitor
    if ($doMonitor) {
        Start-Monitor
    }
    else {
        Write-Host "NO ACTION: 'doMonitor' is false, not invoking Cim Method 'PerformRequiredConfigurationChecks' with Flags '1' (Consistency Check)."
    }
}
else {
    Write-Host "In AutoCorrect mode, skipping Montior"
}

$logItem = [pscustomobject]@{
    CurrentTime                 = (Get-Date).ToString('M\/d\/yyyy h:m:s tt', [System.Globalization.CultureInfo]::InvariantCulture)
    InMaintenanceWindow         = [int]$inMaintenanceWindow
    DoAutoCorrect               = [int]$doAutoCorrect
    DoMonitor                   = [int]$doMonitor
    DoRefresh                   = [int]$doRefresh

    LastAutoCorrect             = $lastAutoCorrect.ToString('M\/d\/yyyy h:m:s tt', [System.Globalization.CultureInfo]::InvariantCulture)
    LastMonitor                 = $lastMonitor.ToString('M\/d\/yyyy h:m:s tt', [System.Globalization.CultureInfo]::InvariantCulture)
    AutoCorrectInterval         = $autoCorrectInterval
    AutoCorrectIntervalOverride = $autoCorrectIntervalOverride
    ConsistencyCheckErrors      = $autoCorrectErrors

    MonitorInterval             = $monitorInterval
    MonitorErrors               = $monitorErrors

    LastRefresh                 = $lastRefresh.ToString('M\/d\/yyyy h:m:s tt', [System.Globalization.CultureInfo]::InvariantCulture)
    RefreshInterval             = $refreshInterval
    RefreshIntervalOverride     = $refreshIntervalOverride
    RefreshErrors               = $refreshErrors

    MaxLcmRuntime               = $maxLcmRuntime
    LcmRuntime                  = $lcmRuntime

    SendDscTaggingDataError     = $sendDscTaggingDataError

} | Export-Csv -Path "$path\LcmControllerSummary.csv" -Delimiter ',' -Append -Force

if ($writeTranscripts) {
    Stop-Transcript
}

#------------------------ LcmController.log cleanup ----------------------------------

$pattern = '(\*{22}\r\nWindows PowerShell transcript start\r\n)((.|\r\n)+?)(End time: \d{14}\r\n\*{22})'
$date = (Get-Date) - $logHistoryTimeSpan

$lcmControllerLogContent = Get-Content -Path "$path\LcmController.log" -Raw
$regexMatches = [regex]::Matches($lcmControllerLogContent, $pattern)

$logEntries = $regexMatches | Where-Object {
    [datetime]::ParseExact((($_.Value -split "\n")[-2] -split ' ')[2].Trim(), 'yyyyMMddHHmmss', $null) -gt $date
}

#$logEntries | Group-Object -Property { [datetime]::ParseExact((($_.Value -split "\n")[-2] -split ' ')[2].Trim(),'yyyyMMddHHmmss',$null).ToString('yy MM dd') }

Write-Host "Log file contained $($regexMatches.Count) entries, after cleanup if contains $($logEntries.Count) entries."
$logEntries.Value | Out-File -FilePath "$path\LcmController.log" -Force

#------------------ LcmControllerSummary.csv cleanup ------------------------------

$summaryContent = Import-Csv -Path "$path\LcmControllerSummary.csv" -Delimiter ','
$filteredSummaryContent = $summaryContent | Where-Object { [datetime]$_.CurrentTime -gt $date }

Write-Host "Summary file contained $($summaryContent.Count) entries, after cleanup if contains $($filteredSummaryContent.Count) entries."
$filteredSummaryContent | Export-Csv -Path "$path\LcmControllerSummary.csv" -Delimiter ',' -Force
'@

configuration DscLcmController {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Monitor', 'AutoCorrect')]
        [string]
        $MaintenanceWindowMode,

        [Parameter(Mandatory = $true)]
        [timespan]
        $MonitorInterval,

        [Parameter(Mandatory = $true)]
        [timespan]
        $AutoCorrectInterval,

        [Parameter()]
        [bool]
        $AutoCorrectIntervalOverride,

        [Parameter(Mandatory = $true)]
        [timespan]
        $RefreshInterval,

        [Parameter()]
        [bool]
        $RefreshIntervalOverride,

        [Parameter(Mandatory = $true)]
        [timespan]
        $ControllerInterval,

        [Parameter()]
        [bool]
        $MaintenanceWindowOverride,

        [Parameter()]
        [timespan]
        $MaxLcmRuntime = (New-TimeSpan -Days 2),

        [Parameter()]
        [timespan]
        $LogHistoryTimeSpan = (New-TimeSpan -Days 90),

        [Parameter()]
        [bool]
        $SendDscTaggingData,

        [Parameter()]
        [bool]
        $WriteTranscripts
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc

    xRegistry DscLcmController_MaintenanceWindowMode
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'MaintenanceWindowMode'
        ValueData = $MaintenanceWindowMode
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_MonitorInterval
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'MonitorInterval'
        ValueData = $MonitorInterval
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_AutoCorrectInterval
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'AutoCorrectInterval'
        ValueData = $AutoCorrectInterval
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_AutoCorrectIntervalOverride
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'AutoCorrectIntervalOverride'
        ValueData = [int]$AutoCorrectIntervalOverride
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_RefreshInterval
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'RefreshInterval'
        ValueData = $RefreshInterval
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_RefreshIntervalOverride
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'RefreshIntervalOverride'
        ValueData = [int]$RefreshIntervalOverride
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_ControllerInterval
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'ControllerInterval'
        ValueData = $ControllerInterval
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_MaintenanceWindowOverride
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'MaintenanceWindowOverride'
        ValueData = [int]$MaintenanceWindowOverride
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_WriteTranscripts
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'WriteTranscripts'
        ValueData = [int]$WriteTranscripts
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_MaxLcmRuntime
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'MaxLcmRuntime'
        ValueData = $MaxLcmRuntime
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_LogHistoryTimeSpan
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'LogHistoryTimeSpan'
        ValueData = $LogHistoryTimeSpan
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscLcmController_SendDscTaggingData
    {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController'
        ValueName = 'SendDscTaggingData'
        ValueData = [int]$SendDscTaggingData
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }

    File DscLcmControllerScript
    {
        Ensure          = 'Present'
        Type            = 'File'
        DestinationPath = 'C:\ProgramData\Dsc\LcmController\LcmController.ps1'
        Contents        = $dscLcmControllerScript
    }

    ScheduledTask DscControllerTask
    {
        DependsOn          = '[File]DscLcmControllerScript'
        TaskName           = 'DscLcmController'
        TaskPath           = '\DscController'
        ActionExecutable   = 'C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe'
        ActionArguments    = '-File C:\ProgramData\Dsc\LcmController\LcmController.ps1'
        ScheduleType       = 'Once'
        RepeatInterval     = $ControllerInterval
        RepetitionDuration = 'Indefinitely'
        StartTime          = (Get-Date)
    }
}
