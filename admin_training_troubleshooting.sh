#!/bin/bash

# Admin Training: Advanced Troubleshooting
# Lesson 11: Node Recovery & Munge Failures

CONTROLLER="slurmctld"
COMPUTE_NODE="c1"
INTERACTIVE=true

while getopts "y" opt; do
  case ${opt} in
    y) INTERACTIVE=false ;;
    *) echo "Usage: $0 [-y] (non-interactive)"; exit 1 ;;
  esac
done

function wait_enter() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "\nPress \033[1;33m[ENTER]\033[0m to continue..."
        read
    else
        echo -e "\n[Non-Interactive] Continuing..."
        sleep 2
    fi
}

function cleanup() {
    echo -e "\n\033[1;31m[*] Cleaning up (Ensuring munge and slurmd are running on $COMPUTE_NODE)...\033[0m"
    docker exec $COMPUTE_NODE pkill munged &> /dev/null
    docker exec $COMPUTE_NODE /usr/sbin/munged &> /dev/null
    docker exec $CONTROLLER scontrol update nodename=$COMPUTE_NODE state=RESUME &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m TROUBLESHOOTING STEP 1: The "Crisis" \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: A researcher reports that their jobs are stuck pending."
echo "You check 'sinfo' and see a suspicious node state."

echo -e "\n[*] breaking munge security on $COMPUTE_NODE..."
docker exec $COMPUTE_NODE pkill munged &> /dev/null

echo "[*] Triggering node DOWN state on controller (simulating timeout)..."
docker exec $CONTROLLER scontrol update nodename=$COMPUTE_NODE state=DOWN reason="Munge failure" &> /dev/null

echo "[*] Waiting for Slurm to detect the failure (10 seconds)..."
sleep 10

echo -e "\n[*] Check Cluster Status (sinfo):"
docker exec $CONTROLLER sinfo

echo -e "\n\033[1;33mDIAGNOSIS TASK:\033[0m"
echo "Note that '$COMPUTE_NODE' is likely in 'down*' or 'drain*' state."
echo "Wait, why is it down? Let's ask Slurm for the 'Reason'."

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m TROUBLESHOOTING STEP 2: Slurm Investigation \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "[*] Running: scontrol show node $COMPUTE_NODE"
docker exec $CONTROLLER scontrol show node $COMPUTE_NODE | grep -E "NodeName|State|Reason"

echo -e "\n[*] Checking Controller Logs (/var/log/slurm/slurmctld.log):"
docker exec $CONTROLLER tail -n 20 /var/log/slurm/slurmctld.log | grep -i "error" | tail -n 5

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "The reason likely says 'Not responding' or 'Munge decode failed'."
echo "This usually points to a clock skew or a stopped munge daemon."

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m TROUBLESHOOTING STEP 3: Resolution \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "1. Fix the underlying issue (Restart Munge)."
echo "2. Resume the node (Slurm won't do this automatically if it was marked DOWN)."

echo -e "\n[*] Restarting Munge on $COMPUTE_NODE..."
docker exec $COMPUTE_NODE /usr/sbin/munged

echo "[*] Attempting to RESUME node..."
docker exec $CONTROLLER scontrol update nodename=$COMPUTE_NODE state=RESUME

echo "[*] Final Verification (sinfo):"
sleep 2
docker exec $CONTROLLER sinfo

echo -e "\n\033[1;32mSUCCESS:\033[0m Node $COMPUTE_NODE is back to IDLE."
wait_enter
