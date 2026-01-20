#!/bin/bash

# Basic Training Script
# Lesson: Output, Environment Variables, and Job Arrays

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

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m BASIC LESSON 1: Where is my output? \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "By default, Slurm writes output to 'slurm-<jobid>.out'."
echo "Let's change that using flags."

wait_enter

echo "[*] Submitting job with custom output and error files..."
# Submitting as 'u1' to simulated user behavior
# We create a directory for them first
docker exec -u u1 c1 mkdir -p /home/u1/basics
docker exec -u u1 c1 sbatch --output=/home/u1/basics/my_job.log \
                           --error=/home/u1/basics/my_job.err \
                           --wrap="echo 'Hello World'; ls /nonexistent_file" \
                           -J basic_io \
                           &> /dev/null

echo "Job submitted. Waiting for completion..."
sleep 5

echo "[*] Checking user directory:"
docker exec -u u1 c1 ls -l /home/u1/basics/

echo -e "\n[*] Content of 'my_job.log' (STDOUT):"
docker exec -u u1 c1 cat /home/u1/basics/my_job.log

echo -e "\n[*] Content of 'my_job.err' (STDERR):"
docker exec -u u1 c1 cat /home/u1/basics/my_job.err

echo -e "\n\033[1;32mTIP:\033[0m Always separate error logs for complex jobs!"

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m BASIC LESSON 2: Magic Variables \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Slurm injects variables into your script at runtime."
echo "These are crucial for parallel workflows."

wait_enter

echo "[*] Submitting a script that prints its own ID and Node..."
CMD='echo "My Job ID is: $SLURM_JOB_ID"; echo "My Node is: $SLURMD_NODENAME"; echo "Submit Dir: $SLURM_SUBMIT_DIR"'

docker exec -u u1 c1 sbatch --output=/home/u1/basics/vars.log \
                           --wrap="$CMD" \
                           -J var_test \
                           &> /dev/null

sleep 5

echo "[*] Result (vars.log):"
docker exec -u u1 c1 cat /home/u1/basics/vars.log

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m BASIC LESSON 3: Job Arrays (The Power Move) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Instead of submitting 100 jobs, submit 1 Array."
echo "Each sub-job gets a unique \$SLURM_ARRAY_TASK_ID."

wait_enter

echo "[*] Submitting an Array of 5 tasks..."
# array=1-5
docker exec -u u1 c1 sbatch --array=1-5 \
                           --output=/home/u1/basics/task_%a.txt \
                           --wrap="echo 'I am task number \$SLURM_ARRAY_TASK_ID'" \
                           -J array_test \
                           &> /dev/null

echo "Submitted. Checking Queue..."
docker exec $CONTROLLER squeue -u u1
sleep 5

echo -e "\n[*] Checking output files (task_*.txt):"
docker exec -u u1 c1 ls -1 /home/u1/basics/task_*.txt

echo -e "\n[*] Content of task_3.txt:"
docker exec -u u1 c1 cat /home/u1/basics/task_3.txt

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m Basic training complete."
