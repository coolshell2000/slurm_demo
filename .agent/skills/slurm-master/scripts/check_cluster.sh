#!/bin/bash
# Slurm Master Skill: Comprehensive Health Check

echo "=== Slurm Cluster Health Report ==="
echo "Time: $(date)"
echo "-----------------------------------"

# 1. Daemon Status
echo "[+] Checking Daemons (ps aux)..."
for node in slurmctld c1 c2 c3; do
    echo -n "  $node: "
    if docker exec $node ps aux | grep -v grep | grep -E "slurmctld|slurmd|munged" > /dev/null; then
        echo "ALIVE"
    else
        echo "CRITICAL: Service missing!"
    fi
done

# 2. Munge Cross-Node Auth
echo -e "\n[+] Checking Munge Authentication..."
for node in slurmctld c1 c2 c3; do
    echo -n "  $node: "
    if docker exec $node bash -c "munge -n | unmunge > /dev/null 2>&1"; then
        echo "OK"
    else
        echo "FAILED (Check keys or daemon)"
    fi
done

# 3. Slurm Node States
echo -e "\n[+] Slurm Node States (sinfo):"
docker exec slurmctld sinfo -o "%10N %10T %20R"

# 4. Job Queue Summary
echo -e "\n[+] Current Queue:"
docker exec slurmctld squeue
