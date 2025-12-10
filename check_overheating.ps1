<#
.SYNOPSIS
    Checks Windows Event Logs for evidence of system overheating.

.DESCRIPTION
    This script analyzes system logs for thermal events that might indicate overheating is the cause of crashes or instability.
    It checks for:
    - Kernel-Power Thermal Zone warnings (Event ID 2)
    - Processor thermal throttling (Event ID 37, 56)
    - Hardware errors (WHEA events)
    - GPU driver timeouts (TDR) often caused by overheating
    - Critical temperature events
    
    The script generates a report in the Downloads folder (default) or a specified directory.
    
    NOTE: This script is READ-ONLY. It does not modify fan speeds or system settings.

.PARAMETER OutputDir
    The directory where the log file will be saved. Defaults to the current user's Downloads folder.

.PARAMETER Help
    Show this help message.

.EXAMPLE
    .\check_overheating.ps1
    Checks for overheating evidence and saves report to Downloads.

.EXAMPLE
    .\check_overheating.ps1 -OutputDir "C:\Logs"
    Checks for overheating and saves report to C:\Logs.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "$env:USERPROFILE\Downloads",

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputDir "overheating_check_$timestamp.txt"

Write-Host "Checking for overheating evidence..." -ForegroundColor Green
Write-Host "Output: $outputFile" -ForegroundColor Yellow

"=" * 80 | Out-File $outputFile
"OVERHEATING DIAGNOSTIC REPORT" | Out-File $outputFile -Append
"Generated: $(Get-Date)" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"`n" | Out-File $outputFile -Append

# 1. Kernel-Power Thermal Events
"`n[1] THERMAL ZONE WARNINGS (Event ID 2 - Overheating Detected)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $thermalEvents = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'; 
        ProviderName = 'Microsoft-Windows-Kernel-Power'; 
        ID           = 2
    } -MaxEvents 50 -ErrorAction SilentlyContinue
    
    if ($thermalEvents) {
        $thermalEvents | Select-Object TimeCreated, Id, Message | Format-List | Out-File $outputFile -Append
        Write-Host "FOUND: Thermal zone warnings detected!" -ForegroundColor Red
    }
    else {
        "No thermal zone warnings found (this is good).`n" | Out-File $outputFile -Append
        Write-Host "No thermal warnings found." -ForegroundColor Green
    }
}
catch {
    "No thermal zone warnings found.`n" | Out-File $outputFile -Append
}

# 2. Processor Thermal Throttling
"`n[2] PROCESSOR THERMAL THROTTLING (Event ID 37 & 56)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $throttleEvents = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'; 
        ProviderName = 'Microsoft-Windows-Kernel-Processor-Power'
    } -MaxEvents 100 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Id -eq 37 -or $_.Id -eq 56 }
    
    if ($throttleEvents) {
        $throttleEvents | Select-Object TimeCreated, Id, Message | Format-List | Out-File $outputFile -Append
        Write-Host "FOUND: CPU thermal throttling events!" -ForegroundColor Red
    }
    else {
        "No CPU thermal throttling detected.`n" | Out-File $outputFile -Append
        Write-Host "No CPU throttling found." -ForegroundColor Green
    }
}
catch {
    "No CPU thermal throttling detected.`n" | Out-File $outputFile -Append
}

# 3. WHEA (Hardware Error Architecture) - Hardware Errors Including Thermal
"`n[3] HARDWARE ERRORS (WHEA - Including Thermal Issues)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $wheaEvents = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'; 
        ProviderName = 'Microsoft-Windows-WHEA-Logger'
    } -MaxEvents 50 -ErrorAction SilentlyContinue
    
    if ($wheaEvents) {
        $wheaEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List | Out-File $outputFile -Append
        Write-Host "FOUND: Hardware errors detected!" -ForegroundColor Yellow
    }
    else {
        "No WHEA hardware errors found.`n" | Out-File $outputFile -Append
        Write-Host "No hardware errors found." -ForegroundColor Green
    }
}
catch {
    "No WHEA hardware errors found.`n" | Out-File $outputFile -Append
}

# 4. Critical Temperature Events
"`n[4] CRITICAL TEMPERATURE EVENTS" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $tempEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
    } -MaxEvents 1000 -ErrorAction SilentlyContinue | 
    Where-Object {
        $_.Message -like "*temperature*" -or 
        $_.Message -like "*thermal*" -or 
        $_.Message -like "*overheat*" -or
        $_.Message -like "*throttle*"
    }
    
    if ($tempEvents) {
        $tempEvents | Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message | Format-List | Out-File $outputFile -Append
        Write-Host "FOUND: Temperature-related events!" -ForegroundColor Yellow
    }
    else {
        "No explicit temperature events found.`n" | Out-File $outputFile -Append
        Write-Host "No temperature events found." -ForegroundColor Green
    }
}
catch {
    "No temperature events found.`n" | Out-File $outputFile -Append
}

# 5. Check Kernel-Power Event 41 with BugcheckCode analysis
"`n[5] KERNEL-POWER EVENT 41 DETAILED ANALYSIS" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $event41 = Get-WinEvent -FilterHashtable @{
        LogName = 'System'; 
        ID      = 41
    } -MaxEvents 10 -ErrorAction SilentlyContinue
    
    if ($event41) {
        foreach ($event in $event41) {
            "TimeCreated: $($event.TimeCreated)" | Out-File $outputFile -Append
            
            # Parse XML to get BugcheckCode
            $xml = [xml]$event.ToXml()
            $bugcheckCode = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'BugcheckCode' } | Select-Object -ExpandProperty '#text'
            $bugcheckParam1 = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'BugcheckParameter1' } | Select-Object -ExpandProperty '#text'
            
            "BugcheckCode: $bugcheckCode" | Out-File $outputFile -Append
            "BugcheckParameter1: $bugcheckParam1" | Out-File $outputFile -Append
            
            # Interpret codes
            if ($bugcheckCode -eq "0") {
                "Interpretation: Clean shutdown or power loss (NOT a crash/overheat)" | Out-File $outputFile -Append
            }
            elseif ($bugcheckCode -eq "116") {
                "Interpretation: VIDEO_TDR_ERROR - GPU driver timeout (possible GPU overheat or driver issue)" | Out-File $outputFile -Append
            }
            elseif ($bugcheckCode -eq "292") {
                "Interpretation: VIDEO_TDR_TIMEOUT_DETECTED - GPU hang (possible GPU overheat)" | Out-File $outputFile -Append
            }
            else {
                "Interpretation: Bugcheck code $bugcheckCode - System crash" | Out-File $outputFile -Append
            }
            
            "-" * 40 | Out-File $outputFile -Append
        }
    }
}
catch {
    "Error analyzing Event 41 details.`n" | Out-File $outputFile -Append
}

# 6. Power Supply Issues (can mimic overheating)
"`n[6] POWER SUPPLY / BATTERY ISSUES" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $powerEvents = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'; 
        ProviderName = 'Microsoft-Windows-Kernel-Power'
    } -MaxEvents 50 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Id -ne 41 -and $_.Id -ne 42 }
    
    if ($powerEvents) {
        $powerEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List | Out-File $outputFile -Append
    }
    else {
        "No power supply issues detected.`n" | Out-File $outputFile -Append
    }
}
catch {
    "No power supply issues detected.`n" | Out-File $outputFile -Append
}

# 7. Display/GPU Driver Timeouts (TDR events)
"`n[7] GPU DRIVER TIMEOUTS (TDR Events - May Indicate GPU Overheat)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    $tdrEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
    } -MaxEvents 1000 -ErrorAction SilentlyContinue | 
    Where-Object {
        $_.Message -like "*display driver*" -or 
        $_.Message -like "*nvlddmkm*" -or 
        $_.Message -like "*amdkmdap*" -or
        $_.Message -like "*timeout*" -or
        $_.ProviderName -like "*Display*"
    }
    
    if ($tdrEvents) {
        $tdrEvents | Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message | Format-List | Out-File $outputFile -Append
        Write-Host "FOUND: GPU driver timeout events!" -ForegroundColor Yellow
    }
    else {
        "No GPU driver timeout events found.`n" | Out-File $outputFile -Append
        Write-Host "No GPU timeout events found." -ForegroundColor Green
    }
}
catch {
    "No GPU driver timeout events.`n" | Out-File $outputFile -Append
}

# 8. Summary and Recommendations
"`n[8] SUMMARY & RECOMMENDATIONS" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append

$overheatingFound = $false
$summary = @()

if ($thermalEvents) {
    $overheatingFound = $true
    $summary += "- CRITICAL: Thermal zone warnings detected - System is OVERHEATING!"
}

if ($throttleEvents) {
    $overheatingFound = $true
    $summary += "- WARNING: CPU thermal throttling detected - CPU overheating"
}

if ($wheaEvents) {
    $summary += "- WARNING: Hardware errors detected - Check hardware health"
}

if ($tdrEvents) {
    $summary += "- WARNING: GPU driver timeouts detected - Possible GPU overheating or driver issue"
}

if ($overheatingFound) {
    "`nOVERHEATING EVIDENCE FOUND!" | Out-File $outputFile -Append
    $summary | Out-File $outputFile -Append
    "`n" | Out-File $outputFile -Append
    "RECOMMENDED ACTIONS:" | Out-File $outputFile -Append
    "1. Clean dust from CPU/GPU heatsinks and fans" | Out-File $outputFile -Append
    "2. Check CPU/GPU temperatures with HWMonitor or HWiNFO64" | Out-File $outputFile -Append
    "3. Reapply thermal paste if temperatures exceed 85°C" | Out-File $outputFile -Append
    "4. Improve case airflow (add fans, remove obstructions)" | Out-File $outputFile -Append
    "5. Check if CPU/GPU fans are spinning properly" | Out-File $outputFile -Append
    
    Write-Host "`n!!! OVERHEATING EVIDENCE FOUND !!!" -ForegroundColor Red
}
else {
    "`nNo clear overheating evidence found in system logs." | Out-File $outputFile -Append
    "`nThis suggests the crashes are more likely due to:" | Out-File $outputFile -Append
    "- Software issues (game bugs, driver problems)" | Out-File $outputFile -Append
    "- GPU driver instability" | Out-File $outputFile -Append
    "- RAM issues" | Out-File $outputFile -Append
    "- Power supply problems" | Out-File $outputFile -Append
    "`n" | Out-File $outputFile -Append
    "However, Windows doesn't always log thermal events before crashes." | Out-File $outputFile -Append
    "To definitively rule out overheating:" | Out-File $outputFile -Append
    "1. Monitor temps in real-time with HWMonitor/HWiNFO64 while gaming" | Out-File $outputFile -Append
    "2. Safe temps: CPU <85°C, GPU <83°C under load" | Out-File $outputFile -Append
    
    Write-Host "`nNo obvious overheating evidence in logs." -ForegroundColor Green
    Write-Host "Recommend monitoring temperatures in real-time." -ForegroundColor Yellow
}

"`n" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"END OF OVERHEATING ANALYSIS" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append

Write-Host "`nReport saved to: $outputFile" -ForegroundColor Green
