#!/bin/bash

# Admin Training: Fairshare & Priority
# Lesson 4: The "Rich vs Poor" Department

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
    echo -e "\n\033[1;31m[*] Cleaning up Accounts and Jobs...\033[0m"
    docker exec $CONTROLLER scancel --state=PENDING &> /dev/null
    # Remove user associations from these accounts
    docker exec $CONTROLLER sacctmgr -i delete user name=u1 account=rich_dept,poor_dept &> /dev/null
    docker exec $CONTROLLER sacctmgr -i delete account name=rich_dept,poor_dept &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LESSON 4: FAIRSHARE (Who pays the bills?) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"

echo "We configured Slurm with:"
echo "   PriorityWeightFairshare=10000"
echo "   PriorityWeightAge=1000"
echo ""
echo "Now we create two Departments:"
echo "1. 'rich_dept' (Fairshare=100)"
echo "2. 'poor_dept' (Fairshare=1)"

wait_enter

echo "[*] Creating Accounts..."
docker exec $CONTROLLER sacctmgr -i add account rich_dept Fairshare=100 &> /dev/null
docker exec $CONTROLLER sacctmgr -i add account poor_dept Fairshare=1 &> /dev/null

echo "[*] Adding User 'u1' to both..."
docker exec $CONTROLLER sacctmgr -i add user u1 account=rich_dept &> /dev/null
docker exec $CONTROLLER sacctmgr -i add user u1 account=poor_dept &> /dev/null

# Force reconfig to ensure shares are calculated
docker exec $CONTROLLER scontrol reconfigure &> /dev/null

echo "[*] Submitting jobs to fill the cluster (blocking jobs)..."
# Submit 10 jobs to fill cores (we only have 6 cores total)
# We use 'normal' account (default) for these blocking jobs
for i in {1..6}; do
    docker exec -u u1 c1 sbatch --account=primary --wrap="sleep 60" -J blocking -o /dev/null &> /dev/null
done

echo "[*] Now submitting COMPETING pending jobs..."
echo "    -> Submitting POOR job first (should be last in priority)"
docker exec -u u1 c1 sbatch --account=poor_dept --wrap="hostname" -J poor_job -o /dev/null

echo "    -> Submitting RICH job second (should jump ahead)"
docker exec -u u1 c1 sbatch --account=rich_dept --wrap="hostname" -J rich_job -o /dev/null

sleep 2

echo -e "\n[*] Checking Queue Priority with 'sprio'..."
# sprio shows the calculation. -l for long format.
docker exec $CONTROLLER sprio -l -o "%.8i %.8u %.10a %.10Y %.10S %.10A %.10p"
echo "(Y=Priority, S=Fairshare, A=Age)"

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "Look at the 'S' (Fairshare) column."
echo "The 'rich_job' has a much higher score than 'poor_job'."
echo "Even though 'rich_job' was submitted LATER, it will run FIRST when a CPU frees up."

wait_enter
