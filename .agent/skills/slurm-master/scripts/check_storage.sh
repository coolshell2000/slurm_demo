#!/bin/bash
# Slurm Master Skill: Disk Usage Diagnostic
# Monitors the disk usage of the Slurm cluster components, with focus on /tmp

echo "=== Slurm Cluster Disk Usage Report ==="
echo "Time: $(date)"
echo "----------------------------------------"

CONTAINERS="slurmctld slurmdbd c1 c2 c3"

# Formatting header
printf "%-15s %-15s %-10s %-10s\n" "CONTAINER" "MOUNT" "USAGE" "STATUS"
printf "%-15s %-15s %-10s %-10s\n" "---------" "---------" "-----" "------"

for container in $CONTAINERS; do
    # Check if container is running
    if ! docker ps -q --filter "name=$container" > /dev/null; then
        printf "%-15s %-15s %-10s %-10s\n" "$container" "N/A" "DOWN" "N/A"
        continue
    fi

    # Get disk usage for /tmp
    # df output: Filesystem 1K-blocks Used Available Use% Mounted on
    USAGE_LINE=$(docker exec "$container" df -h /tmp | tail -n 1)
    PERCENT=$(echo "$USAGE_LINE" | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo "$USAGE_LINE" | awk '{print $6}')

    # Determine status
    STATUS="OK"
    if [ "$PERCENT" -gt 90 ]; then
        STATUS="CRITICAL"
    elif [ "$PERCENT" -gt 75 ]; then
        STATUS="WARNING"
    fi

    printf "%-15s %-15s %-10s %-10s\n" "$container" "$MOUNT" "$PERCENT%" "$STATUS"
done

echo "----------------------------------------"
echo "[+] Root filesystem usage summary:"
docker exec slurmctld df -h / | tail -n 1 | awk '{printf "  Controller Root: %s full (%s available)\n", $5, $4}'
