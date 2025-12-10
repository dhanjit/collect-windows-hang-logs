<#
.SYNOPSIS
    Collects diagnostic logs for troubleshooting Windows system hangs and crashes.

.DESCRIPTION
    This script gathers critical system events from Windows Event Logs, including:
    - Unexpected shutdowns (Event ID 41, 6008)
    - Blue Screen of Death (BSOD) events (Event ID 1001)
    - Critical system errors and driver issues
    - Disk and memory diagnostic results
    - Application crashes
    
    The output is saved to a text file in the Downloads folder (default) or a specified directory.
    
    NOTE: This script is READ-ONLY. It does not modify system settings.

.PARAMETER OutputDir
    The directory where the log file will be saved. Defaults to the current user's Downloads folder.

.PARAMETER Help
    Show this help message.

.EXAMPLE
    .\collect_hang_logs.ps1
    Collects logs and saves them to the Downloads folder.

.EXAMPLE
    .\collect_hang_logs.ps1 -OutputDir "C:\Logs"
    Collects logs and saves them to C:\Logs.
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

# Validate and create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    try {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Host "Created output directory: $OutputDir" -ForegroundColor Yellow
    }
    catch {
        Write-Host "ERROR: Cannot create output directory: $OutputDir" -ForegroundColor Red
        Write-Host "Falling back to Downloads folder..." -ForegroundColor Yellow
        $OutputDir = "$env:USERPROFILE\Downloads"
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputDir "system_hang_analysis_$timestamp.txt"

Write-Host "Collecting system hang diagnostic information..." -ForegroundColor Green
Write-Host "Output will be saved to: $outputFile" -ForegroundColor Yellow

# Create output file
"=" * 80 | Out-File $outputFile
"WINDOWS SYSTEM HANG DIAGNOSTIC REPORT" | Out-File $outputFile -Append
"Generated: $(Get-Date)" | Out-File $outputFile -Append
"Output Directory: $OutputDir" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"`n" | Out-File $outputFile -Append

# 1. Critical System Events - Unexpected Shutdowns (Event ID 41)
"[1] UNEXPECTED SHUTDOWNS (Kernel-Power Event 41)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 41 } -MaxEvents 10 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, Id, LevelDisplayName, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No Event ID 41 found or error accessing logs.`n" | Out-File $outputFile -Append
}

# 2. System Event ID 6008 - Unexpected Shutdown
"`n[2] SYSTEM UNEXPECTED SHUTDOWNS (Event ID 6008)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 6008 } -MaxEvents 10 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, Id, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No Event ID 6008 found or error accessing logs.`n" | Out-File $outputFile -Append
}

# 3. BugCheck Events (BSOD)
"`n[3] BUGCHECK EVENTS (BSODs - Event ID 1001)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 1001; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting' } -MaxEvents 10 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, Id, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No BugCheck events found or error accessing logs.`n" | Out-File $outputFile -Append
}

# 4. Recent Critical Errors
"`n[4] RECENT CRITICAL SYSTEM ERRORS (Last 7 Days)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 50 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No critical errors found or error accessing logs.`n" | Out-File $outputFile -Append
}

# 5. Driver Errors
"`n[5] DRIVER ERRORS" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; Level = 2; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue | 
    Where-Object { $_.ProviderName -like "*driver*" -or $_.Message -like "*driver*" } |
    Select-Object TimeCreated, ProviderName, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No driver errors found.`n" | Out-File $outputFile -Append
}

# 6. Disk Errors
"`n[6] DISK ERRORS" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'disk' } -MaxEvents 20 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, Id, LevelDisplayName, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No disk errors found.`n" | Out-File $outputFile -Append
}

# 7. Memory Diagnostics
"`n[7] MEMORY DIAGNOSTIC RESULTS" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'System'; ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results' } -MaxEvents 5 -ErrorAction SilentlyContinue | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No memory diagnostic results found.`n" | Out-File $outputFile -Append
}

# 8. Application Crashes
"`n[8] APPLICATION CRASHES (Last 7 Days)" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; Level = 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 30 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Message -like "*crash*" -or $_.Message -like "*stopped working*" -or $_.Id -eq 1000 } |
    Select-Object TimeCreated, Id, ProviderName, Message | 
    Format-List | Out-File $outputFile -Append
}
catch {
    "No application crashes found.`n" | Out-File $outputFile -Append
}

# 9. System Information
"`n[9] SYSTEM INFORMATION" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture, CsTotalPhysicalMemory, CsNumberOfProcessors | 
Format-List | Out-File $outputFile -Append

# 10. Check for Minidump files
"`n[10] MEMORY DUMP FILES" | Out-File $outputFile -Append
"-" * 80 | Out-File $outputFile -Append
$dumpPath = "C:\Windows\Minidump"
if (Test-Path $dumpPath) {
    Get-ChildItem $dumpPath -Filter *.dmp | 
    Select-Object Name, Length, LastWriteTime | 
    Format-Table -AutoSize | Out-File $outputFile -Append
}
else {
    "No minidump directory found or no dump files present.`n" | Out-File $outputFile -Append
}

"`n" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append
"END OF REPORT" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append

Write-Host "`nDiagnostic report saved to: $outputFile" -ForegroundColor Green
Write-Host "Please share this file for analysis." -ForegroundColor Yellow
