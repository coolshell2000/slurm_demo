# Slurm Simulation Guide (Docker)

This environment simulates a complete High-Performance Computing (HPC) cluster using Docker. It is based on the [giovtorres/slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster) repository.

## Architecture
- **slurmctld**: The control daemon (the "brain" of the cluster).
- **slurmdbd**: The database daemon for job accounting and user management.
- **mysql**: The MariaDB instance where accounting data is stored.
- **c1, c2**: Compute nodes (where jobs actually run).

## Getting Started

1.  **Build and Start the Cluster**:
    ```bash
    docker-compose up -d
    ```
    *Note: The first build will take several minutes as it compiles Slurm from source into RPMs.*

2.  **Check Status**:
    ```bash
    docker-compose ps
    ```
    Wait until all containers are `healthy`.

3.  **Log into the Control Node**:
    ```bash
    docker exec -it slurmctld bash
    ```

## Learning Slurm (Hands-on)

Once inside the `slurmctld` container, you can practice standard Slurm commands:

### 1. Check Node Status
```bash
sinfo
```
You should see nodes `c1` and `c2` in the `idle` state.

### 2. Run a Simple Job
Run a command on the compute nodes interactively:
```bash
srun -N2 hostname
```
This runs `hostname` on 2 nodes.

### 3. Submit a Batch Script
Create a script (e.g., `job.sh`):
```bash
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=res.txt
#SBATCH --nodes=1
#SBATCH --ntasks=1

echo "Running on $(hostname)"
sleep 10
```
Submit it:
```bash
sbatch job.sh
```
Check progress:
```bash
squeue
```

### 4. Admin Tasks (Great for Interviews)
- **Check node details**: `scontrol show node c1`
- **Drain a node**: `scontrol update node=c1 state=drain reason="Maintenance"`
- **Resume a node**: `scontrol update node=c1 state=resume`
- **Check job accounting**: `sacct`

## Configuration
The Slurm configuration files are located in:
- `/etc/slurm/slurm.conf`
- `/etc/slurm/slurmdbd.conf`

You can modify these files in the `config/` directory on your host machine and restart the cluster to see how changes affect Slurm behavior.
## Monitoring (Grafana & Prometheus)
The cluster includes a pre-configured monitoring stack:
- **Grafana**: [http://localhost:3000](http://localhost:3000) (Admin: `admin` / `admin`)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)

### Quick Start Monitoring
1.  Open Grafana and log in.
2.  Go to **Configuration > Data Sources** and add a **Prometheus** source with URL: `http://prometheus:9090`.
3.  Go to **Create > Import** and use Dashboard ID `4323` (official Slurm dashboard) to visualize your cluster health!
