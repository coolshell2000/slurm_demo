#!/bin/bash

# Admin Training: Accounting & Reporting
# Lesson 10: "Show Me The Money" (Resource Usage)

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
    echo -e "\n\033[1;31m[*] Cleaning up accounts/jobs...\033[0m"
    docker exec $CONTROLLER scancel -u u1 &> /dev/null
    docker exec $CONTROLLER sacctmgr -i delete account name=physics,biology &> /dev/null
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m REPORTING LESSON 1: Generating Data \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "To analyze usage, we need history. Let's create some 'Physics' and 'Biology' jobs."

echo "[*] creating Accounts..."
docker exec $CONTROLLER sacctmgr -i add account physics Description="Physics Dept" Organization="Science" &> /dev/null
docker exec $CONTROLLER sacctmgr -i add account biology Description="Biology Dept" Organization="Science" &> /dev/null
docker exec $CONTROLLER sacctmgr -i add user u1 account=physics,biology &> /dev/null

echo "[*] Submitting synthetic workload (Wait ~10s)..."
# Submit 5 physics jobs
for i in {1..5}; do
    docker exec -u u1 c1 sbatch --account=physics --wrap="sleep 2" -J phys_job -o /dev/null &> /dev/null
done
# Submit 3 biology jobs
for i in {1..3}; do
    docker exec -u u1 c1 sbatch --account=biology --wrap="sleep 2" -J bio_job -o /dev/null &> /dev/null
done
# Submit 1 failed job
docker exec -u u1 c1 sbatch --account=physics --wrap="exit 1" -J fail_job -o /dev/null &> /dev/null

sleep 10 # Wait for jobs to finish

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m REPORTING LESSON 2: 'sacct' (The Forensic Tool) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Use 'sacct' for per-job details. Perfect for 'Why did job 123 fail?'"

echo -e "\n[*] Command: sacct --format=JobID,JobName,Account,State,ExitCode -S now-1hour"
docker exec $CONTROLLER sacct --format=JobID,JobName,Account,State,ExitCode -S $(date -d "1 hour ago" +%H:%M)

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m REPORTING LESSON 3: 'sreport' (The Boss's Tool) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Use 'sreport' for high-level summaries. Perfect for 'Who used the most CPU?'"

echo -e "\n[*] Command: sreport cluster AccountUtilizationByUser Start=now-1hour -t Minutes"
docker exec $CONTROLLER sreport cluster AccountUtilizationByUser Start=$(date -d "1 hour ago" +%H:%M) -t Minutes

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "You should see a breakdown of 'physics' vs 'biology' usage."
echo "Since 'u1' ran jobs in both, you see how much time they billed to each account."

# Note: sreport relies on rollup stats which run periodically (slurmdbd). 
# We forced data generation, but real database rollups might take time.
# However, 'AccountUtilizationByUser' usually queries raw data if recent.

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m You are ready for Monthly Reporting."
