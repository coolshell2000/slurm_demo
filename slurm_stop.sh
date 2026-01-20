#!/bin/bash
# slurm_stop.sh
# Automates the shutdown of the Slurm Docker Cluster and Grafana Monitoring

echo "============================================================"
echo "      Slurm Cluster + Grafana Shutdown Script"
echo "============================================================"

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose not found."
    exit 1
fi

echo "[*] Stopping services with docker-compose..."
docker-compose down

# explicitly kill containers if they are still hanging around (orphans)
echo "[*] Ensuring all specific containers are stopped..."
CONTAINERS=("slurmctld" "slurmdbd" "mysql" "c1" "c2" "c3" "slurmrestd" "prometheus" "grafana" "slurm-exporter" "node-exporter")

for CONTAINER in "${CONTAINERS[@]}"; do
    if docker ps -q -f name=^/${CONTAINER}$ | grep -q .; then
        echo "    -> Force removing stuck container: ${CONTAINER}"
        docker rm -f ${CONTAINER} &> /dev/null
    fi
done

echo ""
echo "============================================================"
echo "      Shutdown Complete."
echo "============================================================"
