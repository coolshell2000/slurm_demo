#!/bin/bash
# slurm_startup.sh
# Automates the startup of the Slurm Docker Cluster and Grafana Monitoring

echo "============================================================"
echo "      Slurm Cluster + Grafana Startup Script"
echo "============================================================"

# 1. Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose not found."
    exit 1
fi

echo "[*] Cleaning up old containers (just in case)..."
# We ignore errors here in case they are already down
docker-compose down &> /dev/null

echo "[*] Starting services with docker-compose..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "Warning: docker-compose returned an error. Using fallback restart for critical services..."
    # The python-based docker-compose on some systems has specific bugs with 'ContainerConfig'
    # We force restart the problematic ones manually if they failed
    docker start mysql || true
    sleep 5
    docker start slurmdbd || true
    sleep 5
    docker start slurmctld || true
fi

echo "[*] Waiting for services to stabilize (10s)..."
sleep 10

echo "[*] Verifying Cluster Status..."
# Force restart compute nodes to ensure they register
docker restart c1 c2 c3 &> /dev/null
sleep 5

# Check if controller is responsive
if docker exec slurmctld sinfo &> /dev/null; then
    echo "    -> Slurm Controller: ONLINE"
    docker exec slurmctld sinfo
else
    echo "    -> Slurm Controller: OFFLINE (Trying to restart...)"
    docker restart slurmctld
    sleep 5
    docker exec slurmctld sinfo
fi

echo ""
echo "[*] Persisting User Accounts..."
# Re-create users on all relevant nodes (idempotent-ish: checks implied by OS or just ensuring existence)
# We set generic passwords "password" for simplicity
CONTAINERS="slurmctld c1 c2 c3"
USERS="u1 u2 u3"

for CONTAINER in $CONTAINERS; do
    echo "    -> Processing $CONTAINER..."
    # Ensure groups exist
    docker exec $CONTAINER groupadd -g 2001 normal_grp 2>/dev/null || true
    docker exec $CONTAINER groupadd -g 2002 debug_grp 2>/dev/null || true
    
    # Create users if missing (home dir is persisted via volume)
    docker exec $CONTAINER useradd -u 2001 -g 2001 -m -s /bin/bash u1 2>/dev/null || true
    docker exec $CONTAINER useradd -u 2002 -g 2001 -m -s /bin/bash u2 2>/dev/null || true
    docker exec $CONTAINER useradd -u 2003 -g 2002 -m -s /bin/bash u3 2>/dev/null || true
    
    # Set passwords
    for U in $USERS; do
        docker exec $CONTAINER bash -c "echo '$U:password' | chpasswd"
    done
done

echo ""
echo "[*] Ensuring permissions for job output..."
docker exec slurmctld chmod 777 /data

echo "[*] Updating Slurm Configuration..."
docker cp config/25.05/slurm.conf slurmctld:/etc/slurm/slurm.conf

echo "[*] Refreshing Slurm Group Cache..."
docker exec slurmctld scontrol reconfigure

echo ""
echo "[*] Monitoring Stack..."
docker restart slurm-exporter &> /dev/null # Ensure it picks up munge key
echo "    -> Grafana:     http://localhost:3000 (admin/admin)"
echo "    -> Node Exp:    http://localhost:9100/metrics"
echo "    -> Slurm Exp:   http://localhost:8080/metrics"

echo ""
echo "============================================================"
echo "      Startup Complete!"
echo "============================================================"
