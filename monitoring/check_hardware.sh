#!/bin/bash

# check_hardware.sh - Monitor hardware health status
# Designed for an HPC environment

HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "--- Hardware Health Report for $HOSTNAME [$DATE] ---"

# 1. Disk Usage Check (Threshold 90%)
echo "[Disk Usage]"
df -h | grep '^/dev/' | awk '{ if($5+0 > 90) print "WARNING: "$1" is at "$5; else print "OK: "$1" is at "$5 }'

# 2. Memory Check (Free memory < 5%)
echo -e "\n[Memory Usage]"
free -m | awk 'NR==2{printf "Total: %sMB, Used: %sMB, Free: %sMB, Usage: %.2f%%\n", $2,$3,$4,$3*100/$2 }'
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
if (( $(echo "$MEM_USAGE > 95.0" | bc -l) )); then
    echo "WARNING: Low memory available!"
else
    echo "OK: Memory usage is within limits."
fi

# 3. CPU Load (Load average > number of cores)
echo -e "\n[CPU Load]"
CORES=$(nproc)
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
echo "Load Average (1min): $LOAD (Cores: $CORES)"
if (( $(echo "$LOAD > $CORES" | bc -l) )); then
    echo "WARNING: High CPU load detected!"
else
    echo "OK: CPU load is stable."
fi

# 4. Hardware Errors (dmesg scan for critical HPC issues)
echo -e "\n[Hardware Log Errors]"

# Define critical patterns for HPC
CRIT_PATTERNS='UNCORRECTABLE|ECC|I/O error|disk error|Out of memory|OOM|Thermal throttling|segfault'

# Define noise patterns to ignore (Bluetooth, Graphics, non-critical SCSI, and systemd noise)
IGNORE_PATTERNS='Bluetooth|hci0|drm|i915|diagnostic page|enclosure|systemd\[1\]|OOM.Killer.Socket|No.ECC.support'

ERRORS=$(dmesg | grep -Ei "$CRIT_PATTERNS" | grep -Eiv "$IGNORE_PATTERNS" | tail -n 5)
if [ -n "$ERRORS" ]; then
    echo "CRITICAL: Significant hardware or system errors found in dmesg:"
    echo "$ERRORS"
else
    # Also check if the broad search catches anything else unexpected
    OTHER_ERRORS=$(dmesg | grep -Ei 'error|fail|critical' | grep -Eiv "$IGNORE_PATTERNS|$CRIT_PATTERNS" | tail -n 3)
    if [ -n "$OTHER_ERRORS" ]; then
        echo "WARNING: Non-critical or unknown events found (Review required):"
        echo "$OTHER_ERRORS"
    else
        echo "OK: No critical hardware errors found in dmesg."
    fi
fi

# 5. NTP Sync status
echo -e "\n[NTP Status]"
if command -v timedatectl &> /dev/null; then
    timedatectl status | grep "synchronized"
else
    echo "INFO: timedatectl not found, skipping NTP check."
fi

echo -e "\n--- End of Report ---"
