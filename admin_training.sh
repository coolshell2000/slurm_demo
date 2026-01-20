#!/bin/bash

# Admin Training Script
# Interactive lesson for limiting users and debugging jobs.

CONTROLLER="slurmctld"
INTERACTIVE=true

# Function to handle flags
while getopts "y" opt; do
  case ${opt} in
    y) INTERACTIVE=false ;;
    *) echo "Usage: $0 [-y] (non-interactive)"; exit 1 ;;
  esac
done

function print_header() {
    echo -e "\n\033[1;34m============================================================\033[0m"
    echo -e "\033[1;36m $1 \033[0m"
    echo -e "\033[1;34m============================================================\033[0m"
}

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
    echo -e "\n\033[1;31m[*] Cleaning up limits and jobs...\033[0m"
    docker exec $CONTROLLER sacctmgr -i modify user u1 set MaxJobs=-1 &> /dev/null
    docker exec $CONTROLLER scancel -u u1 &> /dev/null
    echo "[*] Done."
}

# Register cleanup to run on Exit (normal or interrupt)
trap cleanup EXIT

echo "Checking connectivity..."
if ! docker exec $CONTROLLER sinfo &> /dev/null; then
    echo "Error: Slurm controller is not running. Run ./slurm_startup.sh first."
    exit 1
fi

# ==============================================================================
# LESSON 1: LIMITING USERS
# ==============================================================================
print_header "LESSON 1: The 'Spammy' User (Resource Limits)"
echo "We will simulate User 'u1' trying to flood the cluster."
echo "Currently, u1 has NO limits."

wait_enter

echo "[*] Submitting 5 long-running jobs for u1..."
for i in {1..5}; do
    docker exec -u u1 c1 sbatch --wrap="sleep 60" -J spam_job -o /dev/null &> /dev/null
done

echo "[*] Current Queue (All should be R or PD):"
sleep 1 # Wait for scheduler
docker exec $CONTROLLER squeue -u u1 -o "%.8i %.9P %.8j %.8u %.2t %.10M %.6D %R"

wait_enter

echo -e "\n[*] Now, we act as ADMIN and clamp them down."
echo "    Command: sacctmgr modify user u1 set MaxJobs=1"
docker exec $CONTROLLER sacctmgr -i modify user u1 set MaxJobs=1 &> /dev/null
# Force controller to read new limits immediately
docker exec $CONTROLLER scontrol reconfigure &> /dev/null

echo "[*] Cancelling previous jobs and resubmitting..."
docker exec $CONTROLLER scancel -u u1
sleep 1
for i in {1..5}; do
    docker exec -u u1 c1 sbatch --wrap="sleep 60" -J restrict_job -o /dev/null &> /dev/null
done

echo "[*] Queue after applying MaxJobs=1:"
sleep 1 # Wait for scheduler
docker exec $CONTROLLER squeue -u u1 -o "%.8i %.9P %.8j %.8u %.2t %.10M %.6D %R"

echo -e "\n\033[1;32mOBSERVE:\033[0m Only 1 job is 'R' (Running). The others are 'PD' (Pending)."
echo "Reason: 'AssocJobLimit' (Association Job Limit)."

wait_enter

# ==============================================================================
# LESSON 2: TROUBLESHOOTING
# ==============================================================================
print_header "LESSON 2: Troubleshooting (Why is it pending?)"
echo "We will simulate a job that requests impossible resources."

echo "[*] Submitting a job requesting 1TB of RAM..."
# Requesting 1TB RAM (1000000MB) which definitely doesn't exist on these containers
# parsable output gives just the JOB ID (mostly)
JOB_ID=$(docker exec -u u1 c1 sbatch --mem=1000000 --wrap="hostname" --parsable)
echo "Submitted Job ID: $JOB_ID"

sleep 2

echo "[*] Initial squeue status:"
docker exec $CONTROLLER squeue -j $JOB_ID

echo -e "\n[*] Let's dig deeper with 'scontrol show job'..."
echo "    Command: scontrol show job $JOB_ID"
wait_enter
docker exec $CONTROLLER scontrol show job $JOB_ID | grep -E "JobState|Reason|NumNode"

echo -e "\n\033[1;32mDIAGNOSIS:\033[0m"
echo "JobState=PENDING."
echo "Reason=PartitionNodeLimit or Resources (The node is too small)."

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m You have completed the Admin Bootcamp."
# Trap will handle cleanup
