#!/bin/bash

# Admin Training: User Lifecycle Management
# Lesson 9: Onboarding, Promotion, and Offboarding

CONTROLLER="slurmctld"
INTERACTIVE=true
USER_NAME="intern"
ACCT_NAME="research_team"

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
    echo -e "\n\033[1;31m[*] Cleaning up (Deleting user '$USER_NAME' and account '$ACCT_NAME')...\033[0m"
    docker exec $CONTROLLER scancel -u $USER_NAME &> /dev/null
    docker exec $CONTROLLER sacctmgr -i delete user name=$USER_NAME &> /dev/null
    docker exec $CONTROLLER sacctmgr -i delete account name=$ACCT_NAME &> /dev/null
    # Remove OS users (best effort)
    docker exec $CONTROLLER userdel $USER_NAME &> /dev/null
    docker exec c1 userdel $USER_NAME &> /dev/null
    docker exec c2 userdel $USER_NAME &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LIFECYCLE STEP 1: Onboarding (The New Hire) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: A new intern joins the 'Research Team'."
echo "1. Create Linux User (OS Level)."
echo "2. Create Slurm Account (Project Level)."
echo "3. Add User to Account (Slurm Level)."

wait_enter

echo "[*] Creating OS user '$USER_NAME' on Controller and Nodes..."
docker exec $CONTROLLER useradd -m $USER_NAME
docker exec c1 useradd -m $USER_NAME
docker exec c2 useradd -m $USER_NAME

echo "[*] Creating Slurm Account '$ACCT_NAME'..."
docker exec $CONTROLLER sacctmgr -i add account $ACCT_NAME Description="Deep Learning Research" Organization="Science" &> /dev/null

echo "[*] Adding '$USER_NAME' to '$ACCT_NAME' with Limits..."
# Default limits: MaxJobs=50
docker exec $CONTROLLER sacctmgr -i add user $USER_NAME account=$ACCT_NAME MaxJobs=50 &> /dev/null

echo "[*] Verification:"
docker exec $CONTROLLER sacctmgr show assoc user=$USER_NAME format=Account,User,MaxJobs

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LIFECYCLE STEP 2: Promotion (The Coordinator) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: The intern is doing great. We promote them to 'Coordinator'."
echo "This allows them to manage OTHER users within the '$ACCT_NAME' account."

wait_enter

echo "[*] Updating user to Coordinator..."
docker exec $CONTROLLER sacctmgr -i modify user $USER_NAME set Coordinator=$ACCT_NAME &> /dev/null

echo "[*] Creating and assigning a 'high_prio' QOS..."
# Assume they earned VIP access
docker exec $CONTROLLER sacctmgr -i add qos promo_qos Priority=50 &> /dev/null
docker exec $CONTROLLER sacctmgr -i modify user $USER_NAME set QOS+=promo_qos DefaultQOS=promo_qos &> /dev/null

echo "[*] Verification (Note 'Coord' column if visible, usually implies permissions):"
docker exec $CONTROLLER sacctmgr show user $USER_NAME format=User,DefaultAccount,DefaultQOS,Coordinator

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LIFECYCLE STEP 3: Offboarding (The Departure) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: The internship is over. We must SECURELY disable access."
echo "Do NOT just delete them! We need to keep their job history for accounting."
echo "Instead, we LOCK them out."

wait_enter

echo "[*] 1. The Immediate Lockout (MaxSubmitJobs=0)..."
# This prevents ANY new job submissions immediately
docker exec $CONTROLLER sacctmgr -i modify user $USER_NAME set MaxSubmitJobs=0 &> /dev/null

echo "[*] 2. Kill Active Jobs..."
docker exec $CONTROLLER scancel -u $USER_NAME

echo "[*] 3. Set Expiration Date (No access after today)..."
# Expiration date prevents association usage
docker exec $CONTROLLER sacctmgr -i modify user $USER_NAME set MaxWall=0 &> /dev/null 
# Note: 'MaxWall=0' is a trick if Expiration not supported by simple CLI, 
# but usually we use 'modify user ... set Expiration=...' in newer versions.
# For this demo, MaxSubmitJobs=0 is the key 'soft ban'.

echo "[*] Submitting a test job as '$USER_NAME' (Should FAIL)..."
docker exec -u $USER_NAME c1 sbatch --wrap="hostname" -o /dev/null -J ghost_job
# Use exit code of sbatch to confirm
if [ $? -ne 0 ]; then
    echo -e "\n\033[1;32mSUCCESS:\033[0m Job submission failed as expected."
else
    echo -e "\n\033[1;31mWARNING:\033[0m Job submission succeeded? Check limits."
fi

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m You have managed the full user lifecycle."
