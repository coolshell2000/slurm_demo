#!/bin/bash

# Admin Training: GRES (Generic Resources / GPUs)
# Lesson 11: Managing Accelerators

CONTROLLER="slurmctld"
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
    echo -e "\n\033[1;31m[*] Cleaning up configuration...\033[0m"
    # Revert slurm.conf changes (best effort sed)
    docker exec $CONTROLLER sed -i 's/GresTypes=gpu//g' /etc/slurm/slurm.conf
    docker exec $CONTROLLER sed -i 's/ Gres=gpu:2//g' /etc/slurm/slurm.conf
    docker exec $CONTROLLER rm -f /etc/slurm/gres.conf
    
    # Force reconfig on controller
    docker exec $CONTROLLER scontrol reconfigure &> /dev/null
    
    # Restart c1 to clear GRES state
    docker restart c1 &> /dev/null
    
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m GRES LESSON 1: Configuring FAKE GPUs \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "We don't have real GPUs, but Slurm doesn't know that!"
echo "We will tell Slurm that 'c1' has 2 NVIDIA H100s."

wait_enter

echo "[*] Creating /etc/slurm/gres.conf..."
# Since /etc/slurm is a shared volume, writing this on controller makes it visible to c1 too.
docker exec $CONTROLLER bash -c 'echo "Name=gpu File=/dev/null Count=2" > /etc/slurm/gres.conf'

echo "[*] Updating slurm.conf..."
# 1. Add GresTypes=gpu
docker exec $CONTROLLER sed -i '/ClusterName=/a GresTypes=gpu' /etc/slurm/slurm.conf
# 2. Add Gres=gpu:2 to NodeName=c1
docker exec $CONTROLLER sed -i '/NodeName=c1/s/State=UNKNOWN/Gres=gpu:2 State=UNKNOWN/' /etc/slurm/slurm.conf

echo "[*] Restarting 'c1' computing node..."
# We MUST restart the container because 'slurmd' needs to restart to see the new gres.conf
# and 'pkill' kills the container anyway.
docker restart c1

echo "[*] Waiting for 'c1' to be ready..."
for i in {1..30}; do
    STATUS=$(docker exec $CONTROLLER sinfo -N -n c1 -h -o "%t")
    if [[ "$STATUS" == "idle" || "$STATUS" == "mix" || "$STATUS" == "alloc" ]]; then
        echo "   -> Node c1 is UP ($STATUS)"
        break
    fi
    echo "   -> Waiting for c1... ($STATUS)"
    sleep 2
done

echo "[*] Reconfiguring Controller..."
docker exec $CONTROLLER scontrol reconfigure

echo "[*] Verifying Node GRES Status..."
sleep 2
docker exec $CONTROLLER scontrol show node c1 | grep "Gres"

echo -e "\n\033[1;32mOBSERVE:\033[0m You should see 'Gres=gpu:2'."

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m GRES LESSON 2: Requesting GPUs \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Now we try to use them."

echo "[*] Submitting a job requesting 1 GPU..."
JOB_ID=$(docker exec -u u1 c1 sbatch --gres=gpu:1 --wrap="echo 'I am running on a GPU node!'" --parsable -J gpu_job)
echo "   -> Submitted Job: $JOB_ID"

sleep 3
echo "[*] Check Job Details:"
# If job finished fast, look in history. If running, look in queue.
STATE=$(docker exec $CONTROLLER sacct -j $JOB_ID -n -o State)
echo "   -> Job State: $STATE"
docker exec $CONTROLLER sacct -j $JOB_ID -o JobID,JobName,AllocGRES,State

echo "[*] Submitting a job requesting 10 GPUs (Should Pend)..."
JOB_FAIL=$(docker exec -u u1 c1 sbatch --gres=gpu:10 --wrap="hostname" --parsable -J greedy_gpu)
echo "   -> Submitted Job: $JOB_FAIL"

sleep 2
echo "[*] Queue Status (Reason should be 'Resources' or 'Gres'):"
docker exec $CONTROLLER squeue -j $JOB_FAIL -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m You effectively managed AI infrastructure."
