# JAYJAYs IT Platform - PostInstall Templates

Fixed logging issue:
- `PostInstall_*.log` is the script's clean log.
- `PostInstall_Transcript_*.log` is the PowerShell transcript.
- They are separate files so they do not lock each other.
