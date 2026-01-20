#!/bin/bash
# backfill_simulation.sh

echo "1. CLEANUP: Cancelling old jobs..."
scancel -u u1
sleep 2

echo "----------------------------------------------------------------"
echo "STEP 1: The 'Blocker'"
echo "Submitting a job to occupy Node c1 (2 CPUs) for 2 minutes."
echo "This leaves Node c2 FREE, but the cluster is 'half full'."
# Use u1 (allowed in normal partition)
gosu u1 sbatch -p normal -N1 -n2 --time=00:02:00 --job-name=BLOCKER --wrap="sleep 120"
sleep 2
echo "----------------------------------------------------------------"

echo "STEP 2: The 'Big Job' (High Priority)"
echo "Submitting a job that needs ALL 4 CPUs (Nodes c1+c2)."
echo "It MUST wait for the Blocker to finish."
# This will stay PENDING because c1 is busy
gosu u1 sbatch -p normal -N2 -n4 --time=00:10:00 --job-name=BIG_JOB --wrap="sleep 600"
sleep 2
echo "----------------------------------------------------------------"

echo "STEP 3: The 'Backfill' (Small Jobs)"
echo "Submitting 2 jobs that fit in the empty Node c2."
echo "They only need 1 minute. Slurm sees they finish BEFORE Blocker ends."
echo "So Slurm runs them NOW!"
gosu u1 sbatch -p normal -N1 -n2 --time=00:01:00 --job-name=SMALL_1 --wrap="sleep 60"
gosu u1 sbatch -p normal -N1 -n2 --time=00:01:00 --job-name=SMALL_2 --wrap="sleep 60"
sleep 2

echo "----------------------------------------------------------------"
echo "RESULTS:"
squeue -u u1 -o "%.8i %.9P %.8j %.2t %.10M %.10L %.6D %R"
echo "----------------------------------------------------------------"
echo "Look at the STATE:"
echo "BLOCKER  -> R (Running)"
echo "BIG_JOB  -> PD (Pending - Waiting for resources)"
echo "SMALL_Xx -> R (Running - BACKFILLED!)"
