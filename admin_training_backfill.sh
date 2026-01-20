#!/bin/bash

# Admin Training: Backfill Scheduling
# Lesson 6: Playing Tetris (Filling the Gaps)

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
    echo -e "\n\033[1;31m[*] Cleaning up jobs...\033[0m"
    docker exec $CONTROLLER scancel -u u1 &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LESSON 6: BACKFILL SCHEDULER (Tetris) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario:"
echo "1. We have 2 nodes: c1, c2."
echo "2. Job A is running on c1 (Long)."
echo "3. Job B needs BOTH nodes (Long). It must wait for c1."
echo "4. Job C needs c2 (Short)."
echo ""
echo "In a simple FIFO scheduler, Job C waits behind Job B."
echo "In Backfill, Job C 'skips the line' because it fits in the gap on c2."

wait_enter

# Ensure clean slate
docker exec $CONTROLLER scancel -u u1 &> /dev/null

echo "[*] Submitting Job A (Blocker)..."
# Walltime=10 min. Runs on c1.
docker exec -u u1 c1 sbatch --nodelist=c1 --time=10:00 --wrap="sleep 600" -J blocker -o /dev/null
echo "   -> Job A is running on c1."

echo "[*] Submitting Job B (The Big Waiter)..."
# Walltime=10 min. Needs c1 AND c2. Priority is high naturally (FIFO/Fairshare).
docker exec -u u1 c1 sbatch --nodes=2 --time=10:00 --wrap="hostname" -J big_job -o /dev/null
echo "   -> Job B is PENDING (Resources) waiting for c1."

echo "[*] Queue Check (Job B blocked):"
sleep 1
docker exec $CONTROLLER squeue -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

echo -e "\n[*] Submitting Job C (The Backfill candidate)..."
# Walltime=1 min. Needs c2.
# Important: It must be SHORTER than the time Job B has to wait.
# Job B has to wait ~10 mins for Job A. Job C is 1 min. It FITS!
docker exec -u u1 c1 sbatch --nodelist=c2 --time=01:00 --wrap="hostname" -J backfill -o /dev/null

sleep 2

echo -e "\n[*] Queue Check (Job C should be RUNNING!):"
docker exec $CONTROLLER squeue -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "Job C (backfill) is 'R' (Running) on c2."
echo "Job B (big_job) is still 'PD' (Pending)."
echo "Job C jumped ahead because the scheduler knew it wouldn't delay Job B."

wait_enter
