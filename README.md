# Windows Hang Diagnostic Scripts

A collection of PowerShell scripts designed to help diagnose the root cause of Windows system hangs, freezes, unexpected shutdowns, and crashes.

## ⚠️ Safety & Disclaimer
**These scripts are READ-ONLY.**
- They **do not** make any changes to your system settings, registry, or drivers.
- They **do not** install any software.
- They **only read** from the Windows Event Logs and system information to generate a text report.

## Scripts Overview

### 1. `collect_hang_logs.ps1`
**Purpose:** General system stability diagnosis.
This script gathers a broad range of diagnostic data to identify why a system might be hanging or crashing.
- **Checks for:** Unexpected shutdowns (Event 41), BSODs, critical errors, disk/memory issues, and app crashes.
- **Best for:** General troubleshooting when you don't know why the PC is crashing.

### 2. `check_overheating.ps1`
**Purpose:** Specific check for thermal issues.
This script targets evidence of hardware overheating.
- **Checks for:** Thermal zone warnings, CPU throttling detection, and heat-related hardware errors.
- **Best for:** When computers shut down under heavy load (gaming, rendering) or fans are spinning loudly before a crash.

## Usage

You must run these scripts as **Administrator** because accessing System Event Logs requires elevated privileges.

### How to Run

1.  Open **PowerShell as Administrator**:
    *   Right-click Start button -> **Windows PowerShell (Admin)** or **Terminal (Admin)**.
2.  Navigate to the directory script using `cd` (e.g., `cd D:\Personal\Code\collect-windows-hang-logs`).
3.  Run the desired script:

```powershell
# Run the general diagnostic script
.\collect_hang_logs.ps1

# Run the overheating check script
.\check_overheating.ps1
```

### Options

Both scripts support the following parameters:

*   `-OutputDir`: Specify a custom folder to save the report. (Default: Downloads folder)
*   `-Help`: Display usage information.

**Examples:**
```powershell
# Save logs to C:\MyLogs
.\collect_hang_logs.ps1 -OutputDir "C:\MyLogs"

# View help
.\check_overheating.ps1 -Help
```

## Diagnosing the Results

### Reading `collect_hang_logs.ps1` Output
*   **Event 41 (Kernel-Power):** If you see many of these, your PC is losing power unexpectedly. This is often a PSU (Power Supply) issue or unstable overclock.
*   **BugCheck (BSOD):** Look at the codes.
    *   `0x00000116` usually means GPU driver issues.
    *   `0x0000001A` or `0x00000050` often point to faulty RAM.
*   **Disk Errors:** "Bad block" errors indicate a failing hard drive/SSD.

### Reading `check_overheating.ps1` Output
*   **Thermal Zone Warnings:** If "FOUND", your PC is definitely overheating and shutting down to save itself. **Clean your fans immediately.**
*   **CPU Throttling:** If found, your CPU is hitting its max temp (usually 100°C) and slowing down. Re-paste thermal compound or check cooling.
*   **Clean Logs?** If the script says "No overheating evidence found," it doesn't 100% rule out heat (sometimes it crashes before logging), but it makes it much less likely. Look at PSU or Drivers instead.
