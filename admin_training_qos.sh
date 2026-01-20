#!/bin/bash

# Admin Training: QOS & Preemption
# Lesson 3: The "Get Out Of My Way" Policy

CONTROLLER="slurmctld"
INTERACTIVE=true

# Function to handle flags
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
    echo -e "\n\033[1;31m[*] Cleaning up QOS and jobs...\033[0m"
    docker exec $CONTROLLER scancel -u u1 &> /dev/null
    # Remove user associations to optional QOS before deleting QOS
    docker exec $CONTROLLER sacctmgr -i modify user u1 set QOS=normal &> /dev/null
    docker exec $CONTROLLER sacctmgr -i delete qos critical_qos,normal_qos &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m LESSON 3: PREEMPTION (The VIP Lane) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"

echo "We will create two Quality of Service (QOS) levels:"
echo "1. 'normal_qos'   (PreemptMode=Requeue) -> The victim"
echo "2. 'critical_qos' (Preempt=normal_qos)  -> The bully"

wait_enter

echo "[*] Configuring QOS in database..."
# Create QOS
docker exec $CONTROLLER sacctmgr -i add qos normal_qos PreemptMode=Requeue Flags=DenyOnLimit &> /dev/null
docker exec $CONTROLLER sacctmgr -i add qos critical_qos Preempt=normal_qos Priority=1000 &> /dev/null

# Allow u1 to use them
echo "[*] Granting 'u1' access to these QOS..."
docker exec $CONTROLLER sacctmgr -i modify user u1 set QOS+=normal_qos,critical_qos &> /dev/null

# Force reconfig (sometimes needed for QOS logic)
docker exec $CONTROLLER scontrol reconfigure &> /dev/null

echo "[*] Flooding the cluster with 'normal_qos' jobs (filling all cores)..."
# We have 3 nodes * 2 CPUs = 6 CPUs total. We'll submit 6 jobs.
for i in {1..6}; do
    docker exec -u u1 c1 sbatch --qos=normal_qos --wrap="sleep 60" -J low_prio -o /dev/null &> /dev/null
done

echo "[*] Cluster Status (Full of low priority):"
sleep 1
docker exec $CONTROLLER squeue -o "%.8i %.9P %.8j %.8u %.8M %.10q %.6D %R"

wait_enter

echo -e "\n[*] \033[1;31mSUBMITTING CRITICAL JOB!\033[0m (Requires 2 CPUs)"
# This job needs 2 CPUs. The cluster is full. It MUST kill something to run.
docker exec -u u1 c1 sbatch --qos=critical_qos --nodes=1 --ntasks=2 --wrap="echo 'I AM IMPORTANT!'; sleep 10" -J VIP_JOB -o /dev/null

sleep 2

echo -e "\n[*] Cluster Status (Watch the 'ST' column):"
# We expect to see 'PD' (requeued) for some low_prio jobs and 'R' for the VIP job
docker exec $CONTROLLER squeue -o "%.8i %.9P %.8j %.8u %.8M %.10q %.2t %R"

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "1. The 'VIP_JOB' is 'R' (Running)."
echo "2. One or more 'low_prio' jobs are 'PD' (Pending) with Reason 'Preempted' or 'JobHeld'."
echo "   (Since we set PreemptMode=REQUEUE, they were put back in line)."

wait_enter
