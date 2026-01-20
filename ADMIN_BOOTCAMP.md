# Slurm Administrator Bootcamp

Welcome to Level 2. You know how to submit jobs; now learn how to control *who* can submit *what* and *when*.

This guide focuses on **sacctmgr** (Slurm Account Manager), the command center for policies, limits, and enforcing fair play.

---

## 1. The Hierarchy: Clusters, Accounts, and Users
Slurm organizes entities in a hierarchy:
`Cluster` -> `Account` -> `User`

*   **Account**: Not an OS user! It's a "bank account" or "project" (e.g., `physics_dept`, `genome_project`).
*   **Association**: The link between a User and an Account. This is where we set **Limits**.

## 2. Setting Limits (The "Bad User" Scenario)
Imagine user `u1` is flooding the cluster with 1,000 tiny jobs, choking the scheduler.
As an admin, you can limit them without banning them.

**Key Command:**
```bash
sacctmgr -i modify user u1 set MaxJobs=2
```
Now, `u1` can submit 1,000 jobs, but only **2** will run at a time. The rest wait in the queue.

Common Limits:
*   `MaxJobs`: Max running jobs.
*   `MaxSubmitJobs`: Max pending + running jobs.
*   `MaxCPUs`: Max cores a user can grab at once.
*   `MaxWallDuration`: Max time a job can run (e.g., "Student" account = 1 hour, "Faculty" = 7 days).

---

## 3. Quality of Service (QOS)
QOS allows you to create "fast lanes" and "slow lanes".

*   **Preemption**: A `high_prio` QOS job can effectively "pause" or "kill" a `low_prio` job to take its resources immediately.
*   **Priority Boost**: Jobs in `critical` QOS get a massive priority score boost (+1000) so they jump to the front of the line.

**Assignments**:
You typically assign QOS to an Association (User+Account) or a Partition.

---

## 4. Debugging "Why is my job pending?"
Users will incorrectly scream "The cluster is broken!" when their jobs don't start. It is your job to use `scontrol` to find the truth.

**The Golden Command:**
```bash
scontrol show job <JOB_ID>
```

Look for `JobState` and `Reason`:
*   `Reason=Resources`: Cluster is full. Normal.
*   `Reason=Priority`: Other jobs have higher priority. Normal.
*   `Reason=AssociationJobLimit`: User hit their `MaxJobs` limit. (See Section 2).
*   `Reason=QOSMaxCpuPerUserLimit`: User hit a QOS policy.
*   `Reason=Dependency`: Waiting for another job.
*   **`Reason=ReqNodeNotAvail`**: Often means the user requested a feature that doesn't exist (e.g., `--constraint=gpu` on a cpu-only node).

---

## 5. Preemption (The "Get Out Of My Way" Policy)
In busy clusters, you might want "Critical" jobs to start *immediately*, even if the cluster is full. To do this, Slurm must **kill** or **pause** (requeue) running lower-priority jobs.

1.  **Configure `slurm.conf`**:
    *   `PreemptType=preempt/qos`: Use QOS to decide who bullies whom.
    *   `PreemptMode=REQUEUE`: Don't kill the victim; just put them back in the queue (PD) to restart later.

2.  **Configure QOS**:
    *   `sacctmgr add qos critical_qos Preempt=normal_qos`
    *   This tells Slurm: "Jobs in `critical_qos` are allowed to kill jobs in `normal_qos`."

---

## 6. Fairshare (The "Rich vs Poor" Policy)
Fairshare ensures that over time, all groups get their allocated slice of the pie.
**Formula:** `Priority = Fairshare_Weight * (Assigned_Share - Effective_Usage)`

*   **Scenario**:
    *   `Physics` has Share=100.
    *   `Chemistry` has Share=1.
*   **Result**: If `Chemistry` has managed to run *any* jobs recently, their priority drops to zero. `Physics` jobs will almost always jump to the front of the queue until they have "spent" their credit.

---

## 7. Operations (Draining & Reservations)
Admins must often take nodes offline for hardware repair or reserve them for dedicated usage.

*   **Draining**: `scontrol update node=c1 state=DRAIN reason="Memory errors"`
    *   Stops NEW jobs from starting.
    *   Allows RUNNING jobs to finish.
    *   State becomes `drng` (draining) then `drained`.
*   **Reservations**: `scontrol create reservation starttime=now duration=60 nodes=c1 user=root`
    *   Creates a "VIP" access window.
    *   Only `user=root` can run jobs on `c1` for the next hour.
    *   Useful for scheduled maintenance or urgent demos.

---

## 8. Backfill Scheduling (Tetris)
The default scheduler (FIFO) is inefficient. If a large job is waiting for resources, the cluster might sit half-empty.
**Backfill** looks for small jobs that can run *now* without delaying the start time of the large job.

*   **Scenario**:
    *   `Job A` runs on Node 1 (10 hours).
    *   `Job B` needs Node 1 + Node 2 (10 hours). It waits for Job A.
    *   `Node 2` is currently EMPTY.
*   **Result**:
    *   FIFO: Node 2 sits empty for 10 hours.
    *   Backfill: A 1-hour `Job C` can run on Node 2 *right now* because it will finish long before Job A does.

---

## Hands-On Training
1.  **Limits & Debug**: `./admin_training.sh`
2.  **Preemption**: `./admin_training_qos.sh`
3.  **Fairshare**: `./admin_training_fairshare.sh`
4.  **Operations**: `./admin_training_ops.sh`
## 9. User Lifecycle (Onboard, Promote, Fire)
Managing users is a daily task.
1.  **Onboarding**:
    *   OS Level: `useradd -m newhire` (Must exist on ALL nodes!)
    *   Slurm Level: `sacctmgr add user newhire account=research`
2.  **Promotion (Coordinator)**:
    *   `sacctmgr modify user newhire set Coordinator=research`
    *   This user can now run `sacctmgr` to add/remove other users *within* the `research` account. They don't need root!
3.  **Offboarding**:
    *   **NEVER DELETE** a user instantly! You lose their job history (Accounting).
    *   **Lock them out**: `sacctmgr modify user newhire set MaxSubmitJobs=0`
    *   Cancel jobs: `scancel -u newhire`

---

## 10. Accounting & Reporting (Monthly Reports)
Your manager asks: "Who used the cluster the most this month?"
Do NOT write a script to grep logs. Use Slurm's built-in tools.

*   **`sacct`**: Job-level detail.
    *   "Why did Job 123 fail?" -> `sacct -j 123`
    *   "Show me all failed jobs today" -> `sacct --state=FAILED -S 00:00`
*   **`sreport`**: High-level summaries.
    *   "Show utilization by Account" -> `sreport cluster AccountUtilizationByUser -t Minutes`
    *   "Show Top Users" -> `sreport user TopUsage`

---

## 11. Managing Accelerators (GRES/GPUs)
HPC is now AI-centric. Admins must manage Generic Resources (GRES), usually GPUs.
*   **`gres.conf`**: Maps logical names (`gpu:0`) to physical device files (`/dev/nvidia0`).
*   **`slurm.conf`**: Tells the controller which nodes have these resources (`NodeName=c1 Gres=gpu:2`).
*   **Submitting**: `sbatch --gres=gpu:1 ...` or `sbatch --gpus=1 ...`

---

## 12. Advanced Troubleshooting (Node Recovery)
HPC clusters fail. When a node goes `DOWN`, you must act quickly.

1.  **Check the Reality**: `sinfo`
    *   `down*`: Node is offline and has a reason.
    *   `drain`: Node is finishing jobs but won't take new ones.
2.  **Find the "Why"**: `scontrol show node <NAME>`
    *   Look for the `Reason` field. Common reasons: `Not responding`, `Munge decode failed`, `Low memory`.
3.  **Inspect the Logs**:
    *   Controller Log: `/var/log/slurm/slurmctld.log` (Watch for communication errors).
    *   Compute Log: `/var/log/slurm/slurmd.log` (Watch for daemon startup issues).
4.  **The Repair**:
    *   Fix the service: `systemctl restart munge` or `systemctl restart slurmd`.
    *   **CRITICAL**: Slurm often marks nodes `DOWN` to protect jobs. Once fixed, you **MUST** manually tell Slurm the node is okay:
    *   `scontrol update nodename=c1 state=RESUME`

---

## Hands-On Training
### Basics
1.  **Workflows**: `./workflow_training.sh` (Dependencies)
2.  **Basics**: `./basic_training.sh`

### Admin Scenarios
3.  **Limits & Debug**: `./admin_training.sh`
4.  **Preemption**: `./admin_training_qos.sh`
5.  **Fairshare**: `./admin_training_fairshare.sh`
6.  **Operations**: `./admin_training_ops.sh`
7.  **Backfill**: `./admin_training_backfill.sh`
8.  **User Management**: `./admin_training_users.sh`
9.  **Accounting**: `./admin_training_accounting.sh`
10. **Accelerators (GRES)**: `./admin_training_gres.sh`
11. **Troubleshooting**: `./admin_training_troubleshooting.sh`

