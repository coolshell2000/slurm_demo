---
name: Slurm Master
description: Advanced Slurm cluster administration, security (Munge) management, resource scheduling (GRES/GPU), and monitoring.
---

# Slurm Master Skill (Refined)

## Overview
This skill provides a framework for managing production-grade Slurm clusters. It emphasizes resilience, manual service management (when standard tools fail), and advanced scheduler tuning for AI/HPC workloads.

## Core Operational Principles

### 1. The "Resilient Admin" Mindset
- **Service Management**: Standard `systemctl` or `service` commands may be absent in containerized or minimal Linux builds. Always fallback to direct binary execution (e.g., `/usr/sbin/munged`, `/usr/sbin/slurmd`) and `pkill/kill` for process control.
- **Node Persistence**: Slurm is "sticky." If a node is marked `DOWN`, resolving the root cause is only step 1. You **MUST** manually `RESUME` the node via `scontrol`.

### 2. Deep Troubleshooting Workflow
When a job fails to run or a node is unhealthy:
1.  **Identity Check**: Verify `Munge` locally and cross-node.
    - Local: `munge -n | unmunge`
    - Cross-node: Generate on node A, decode on node B.
2.  **Resource Check**: Use `scontrol show node <name>` to check `FreeMem`, `CPUAlloc`, and `State`.
3.  **Scheduler Insight**: Use `sdiag` to check backfill depth and scheduler cycles. Large `Backfill` cycle times indicate a need for tuning.

## Common Scenarios & Playbooks

### Scenario A: Munge Auth Failure (Protocol authentication error)
- **Likely Cause**: Clock skew, mismatched `/etc/munge/munge.key`, or insecure log permissions.
- **Action**: 
    1. Check `munged` process. 
    2. **Fix Permissions**: If logs/pidfiles are "insecure," run the "Scorched Earth" fix: 
       `chown -R root:root /var/log/munge /var/lib/munge /etc/munge /run/munge`.
    3. Restart daemon using `/usr/sbin/munged`.

### Scenario B: GRES/GPU Missing (Job pending with "Gres")
- **Likely Cause**: `slurmd` started before `gres.conf` was populated or GRES was added to `slurm.conf`.
- **Action**: Update `slurm.conf` and `gres.conf`. Restart `slurmd` on the compute node. Run `scontrol reconfigure` on the controller.

### Scenario C: Unresponsive Node (DOWN*)
- **Likely Cause**: Compute node network issue or daemon crash.
- **Action**: Check connectivity. Restart `slurmd`. If it remains `DOWN`, check `/var/log/slurm/slurmctld.log` for "not responding" messages.

### Scenario D: Job Failure "Disk space" or "No space left on device"
- **Likely Cause**: `/tmp` or job spool directory is full on a compute node.
- **Action**: 
    1. Run `./scripts/check_storage.sh` to identify the full volume.
    2. Check for abandoned job directories in `/data` or `/tmp`.
    3. If `/tmp` is a `tmpfs`, consider increasing its size or cleaning old sessions.

## Diagnostic Helper Commands

| Task | Command |
| :--- | :--- |
| Cluster Health | `./scripts/check_cluster.sh` |
| Disk/Storage Health | `./scripts/check_storage.sh` |
| User Activity Report | `./scripts/check_usage.sh` |
| Node Reason | `scontrol show node <node> \| grep Reason` |
| Accounting Audit | `sacct -S <time> --format=JobId,State,ExitCode` |
| Priority Check | `sprio -w` |

---
**Authoritative Source**: This skill is based on the [Barry Tao Admin Training Suite](ADMIN_BOOTCAMP.md).
