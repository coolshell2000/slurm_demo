# Learning Slurm: Core Concepts

This guide breaks down Slurm into simple concepts using the example scripts provided in your simulation environment.

## 1. The Basics: Jobs and Resources
In Slurm, everything is a **Job**. You don't just "run a command"; you "request resources to run a command."

| Script | Key Concept | Why it matters |
| :--- | :--- | :--- |
| `simple_hostname.sh` | **Directives (`#SBATCH`)** | Teaches you how to tell Slurm what the job needs (time, nodes, outputs). |
| `cpu_intensive.sh` | **CPU Allocation** | Shows how Slurm limits a job to specific CPUs so it doesn't starve other jobs. |

**Try this:** Compare `srun hostname` (Interactive) with `sbatch /root/examples/jobs/simple_hostname.sh` (Batch). One waits for completion; the other returns immediately.

---

## 2. Architecture: Partitions and Nodes
*   **Node**: A single machine (`c1`, `c2`).
*   **Partition**: A group of nodes (like a "queue"). In this cluster, we have the `normal` partition.

| Script | Key Concept | Why it matters |
| :--- | :--- | :--- |
| `multi_node.sh` | **Parallelism** | Uses `--nodes=2` to ensure the job spans across both `c1` and `c2`. |

---

## 3. Workflow: States and Monitoring
When you submit a job, it goes through a lifecycle:
1.  **PENDING (PD)**: Waiting for resources (e.g., node is down or full).
2.  **RUNNING (R)**: Actively executing.
3.  **COMPLETED (CD)**: Finished successfully.

**Challenge**: Use `scontrol update node=c1 state=drain reason="testing"` then submit a job. It will stay **PD**. Change it back to `resume` to see it move to **R**.

---

## 4. Advanced: Efficiency and Logic
Real HPC workloads are rarely single jobs. They use arrays and dependencies.

| Script | Key Concept | Why it matters |
| :--- | :--- | :--- |
| `array_job.sh` | **Job Arrays** | Submits 10 identical tasks with one command. Great for processing 1,000 files at once. |
| `job_dependency.sh`| **Dependencies** | Ensures Job B only starts if Job A completes successfully. Vital for multi-stage pipelines. |

---

## 🔍 Commands Cheat Sheet for your Interview

### For Users (Job Submission)
- `sbatch <file>`: Submit script for background execution.
- `squeue`: View the status of all current jobs.
- `scancel <jobid>`: Kill a job.

### For Users (Job Selection)
- `srun -p <partition> ...`: Target a specific group of nodes.
- `sbatch -p <partition> ...`: Submit to a specific partition.
- `sinfo`: View node and partition health.
- `sacct`: View history (great for answering "How many jobs did User X run last week?").

### For Administrators (Queue & Security)
- `scancel <jobid>`: Kill a specific job.
- `scancel -u <user>`: Kill all jobs for a specific user.
- `scancel --state=PENDING`: Purge all waiting jobs.
- **Immediate Rejection**: Set `EnforcePartLimits=ALL` in `slurm.conf` to stop unauthorized jobs from ever entering the queue.
- **Backfill Scheduling**: The scheduler fills "holes" in the timeline with smaller/shorter jobs without delaying the highest priority job.

---

## 5. The "Tetris" Master: Backfill Scheduler
Imagine a "Big Job" needs all nodes for 2 days, but it can't start until Saturday.
- **Default Scheduler**: Might leave the cluster empty until Saturday.
- **Backfill Scheduler**: Looks for "Small Jobs" that can finish *before* Saturday and runs them now.

**Key Rule**: Backfill never delays the highest priority job. It only uses "extra" time windows.

> [!TIP]
> Inside the `slurmctld` container, run `man sbatch` or `man scontrol`. Slurm's manuals are excellent and a "pro" way to find flags during an interview.
