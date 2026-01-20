#!/bin/bash
#SBATCH --job-name=oversized_job
#SBATCH --partition=debug
#SBATCH --time=00:03:00  # Requesting 3 minutes (Limit is 2)
#SBATCH --output=/data/oversized_job.out

echo "If you see this, the Time Limit failed!"
sleep 180
