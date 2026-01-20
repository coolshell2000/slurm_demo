#!/bin/bash

# Workflow Training Script
# Lesson: Job Dependencies (Pipelines)

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
echo -e "\033[1;36m WORKFLOW LESSON 1: The Simple Chain (A -> B -> C) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "We will build a pipeline: Preprocess -> Process -> Report"
echo "Job B won't start until Job A succeeds."

wait_enter

echo "[*] Submitting Job A: Preprocess (5s)..."
JOB_A=$(docker exec -u u1 c1 sbatch --parsable --wrap="sleep 5; echo 'Done A'" -J preprocess)
echo "   -> Job A ID: $JOB_A"

echo "[*] Submitting Job B: Process (Depends on A)..."
# --dependency=afterok:<JOBID>
JOB_B=$(docker exec -u u1 c1 sbatch --parsable --dependency=afterok:$JOB_A --wrap="sleep 5; echo 'Done B'" -J process)
echo "   -> Job B ID: $JOB_B"

echo "[*] Submitting Job C: Report (Depends on B)..."
JOB_C=$(docker exec -u u1 c1 sbatch --parsable --dependency=afterok:$JOB_B --wrap="echo 'Report Generated'" -J report)
echo "   -> Job C ID: $JOB_C"

echo -e "\n[*] Current Queue (Notice 'Dependency' reason):"
docker exec $CONTROLLER squeue -u u1 -o "%.8i %.9P %.8j %.8u %.2t %.10M %.6D %R"

echo -e "\n[*] Watching queue (Press Ctrl+C to stop watching, or wait 15s)..."
# Simple wait loop
for i in {1..7}; do
    sleep 2
    echo "   Time: $((i*2))s..."
    docker exec $CONTROLLER squeue -u u1 -o "%.8i %.9P %.8j %.8u %.2t %.10M %.6D %R" | grep -E "$JOB_A|$JOB_B|$JOB_C"
done

wait_enter

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m WORKFLOW LESSON 2: Failure Chains (The Broken Link) \033[0m"
echo -e "\033[1;34m============================================================\033[0m"
echo "What happens if Job A fails?"

echo "[*] Submitting Job A (will fail)..."
JOB_FAIL=$(docker exec -u u1 c1 sbatch --parsable --wrap="exit 1" -J fail_job)
echo "   -> Job ID: $JOB_FAIL"

echo "[*] Submitting Job B (Depends on A success)..."
JOB_WAIT=$(docker exec -u u1 c1 sbatch --parsable --dependency=afterok:$JOB_FAIL --wrap="echo 'I should not run'" -J wait_job)
echo "   -> Job ID: $JOB_WAIT"

sleep 5

echo -e "\n[*] Check Job Status:"
docker exec $CONTROLLER sacct -j $JOB_FAIL,$JOB_WAIT -o JobID,JobName,State,ExitCode

echo -e "\n\033[1;32mOBSERVE:\033[0m"
echo "Job A is 'FAILED'. Job B is 'DependencyNeverSatisfied' (or Cancelled)."

wait_enter

echo -e "\n\033[1;32mCONGRATULATIONS!\033[0m Workflow training complete."
