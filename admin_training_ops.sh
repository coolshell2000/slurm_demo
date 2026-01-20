#!/bin/bash

# Admin Training: Operations
# Lesson 5: Draining Nodes and Reservations

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
    echo -e "\n\033[1;31m[*] Cleaning up (Resuming nodes, removing reservations)...\033[0m"
    docker exec $CONTROLLER scontrol update node=c2 state=RESUME &> /dev/null
    # Delete all reservations
    RSV_LIST=$(docker exec $CONTROLLER scontrol show reservation -o | grep "ReservationName=" | awk -F' ' '{print $1}' | awk -F'=' '{print $2}')
    for r in $RSV_LIST; do
        docker exec $CONTROLLER scontrol delete reservationname=$r &> /dev/null
    done
    docker exec $CONTROLLER scancel -u u1 &> /dev/null
    echo "[*] Done."
}

trap cleanup EXIT

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m OPERATIONS LESSON 1: The Broken Node (Draining) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: Node 'c2' has a fan failure. We need to fix it."
echo "We don't want to kill running jobs, just stop NEW ones."

wait_enter

echo "[*] Setting c2 to DRAINING state..."
# Reason is mandatory!
docker exec $CONTROLLER scontrol update node=c2 state=DRAIN reason="Fan Replacement"

echo "[*] Checking Node Status (sinfo):"
docker exec $CONTROLLER sinfo

echo -e "\n[*] Submitting a job that needs 2 Nodes..."
# We have c1 (idle) and c2 (drained). A 2-node job should hang.
JOB_ID=$(docker exec -u u1 c1 sbatch --nodes=2 --wrap="hostname" --parsable -J drain_test)
echo "Submitted Job: $JOB_ID"

sleep 2
echo "[*] Queue Status:"
docker exec $CONTROLLER squeue -j $JOB_ID -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

echo -e "\n\033[1;32mOBSERVE:\033[0m Job is PENDING with Reason 'ReqNodeNotAvail, UnavailableNodes:c2'."
echo "Slurm knows c2 is broken and waits."

wait_enter

echo "[*] Maintenance complete. Resuming c2..."
docker exec $CONTROLLER scontrol update node=c2 state=RESUME

sleep 2
echo "[*] Queue Status (Job should run):"
docker exec $CONTROLLER squeue -j $JOB_ID -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m OPERATIONS LESSON 2: Reservations (The VIP Room) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "Scenario: Someone needs 'c2' all to themselves for a demo."
echo "We create a RESERVATION."

wait_enter

echo "[*] Creating Reservation for user 'root' only on c2..."
# duration=10 minutes. flags=maint,ignore_jobs (this forces it even if busy, effectively) 
# Usually we just use `flags=ignore_jobs` to create it.
# user=root means ONLY root can use it. u1 cannot.
docker exec $CONTROLLER scontrol create reservation starttime=now duration=10 user=root nodes=c2 flags=ignore_jobs reservationname=maintenance_res

echo "[*] Submitting normal job (u1) requesting c2..."
JOB_FAIL=$(docker exec -u u1 c1 sbatch --nodelist=c2 --wrap="hostname" --parsable -J rsv_fail)
echo "User u1 submitted: $JOB_FAIL"

echo "[*] Queue Status:"
sleep 1
docker exec $CONTROLLER squeue -j $JOB_FAIL -o "%.8i %.9P %.8j %.8u %.2t %.6D %R"

echo -e "\n\033[1;32mOBSERVE:\033[0m Reason='ReqNodeNotAvail, Reserved'."
echo "u1 is locked out."

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m You can now manage hardware lifecycles."
