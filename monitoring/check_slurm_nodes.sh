#!/bin/bash

# check_slurm_nodes.sh - Monitor Slurm node health

echo "--- Slurm Node Health Check ---"

# 1. Nodes in non-idle/non-alloc states
echo "[Node States]"
sinfo -N -o "%10P %.5a %.10T %.15f %N" | grep -v 'idle\|alloc' | head -n 20

# 2. Nodes with Reason for being Down/Drained
echo -e "\n[Down/Drained Nodes with Reason]"
sinfo -R

# 3. Check for 'Nodelist' and 'Reason' using scontrol for more detail on specific nodes
echo -e "\n[Detailed Node Failures]"
MISSING_NODES=$(sinfo -h -t down,drain,fail -o "%N" | xargs)
if [ -n "$MISSING_NODES" ]; then
    for node in $(echo $MISSING_NODES | tr ',' ' '); do
        echo "Node: $node"
        scontrol show node $node | grep -E 'State|Reason'
    done
else
    echo "OK: All nodes appear to be healthy or in use."
fi

# 4. Munge status check
echo -e "\n[Munge Status]"
if munge -n | unmunge &> /dev/null; then
    echo "OK: Munge is working correctly."
else
    echo "CRITICAL: Munge failure detected!"
fi

echo -e "\n--- End of Slurm Report ---"
