#!/bin/bash
# Slurm Master Skill: User Activity Report
# Reports cluster usage by user, ranked by total CPU time, with last activity date.

echo "=== Slurm Cluster User Activity Report ==="
echo "Report generated at: $(date)"
echo "-------------------------------------------"

# Columns in sacct: User, CPUTimeRAW, End, State
# -a: all users
# -X: omit step lines
# --noheader: simplify parsing
RAW_DATA=$(docker exec slurmctld sacct -a -X --format=User,CPUTimeRAW,End,State --noheader)

if [[ -z "$RAW_DATA" ]]; then
    echo "No accounting data found. Is slurmdbd active?"
    exit 0
fi

# Print header
printf "%-12s %-12s %-12s %-20s\n" "USER" "JOBS" "TOT_CPU(S)" "LAST_FINISHED"
printf "%-12s %-12s %-12s %-20s\n" "----" "----" "----------", "-------------"

# Print data and sort it, then append to report
echo "$RAW_DATA" | awk '
{
    user = $1; cpu_time = $2; end_time = $3;
    if (user != "" && user != "slurm") {
        total_cpu[user] += cpu_time;
        job_count[user]++;
        if (end_time > latest_end[user] && end_time != "Unknown") latest_end[user] = end_time;
    }
}
END {
    for (u in total_cpu) {
        printf "%-12s %-12d %-12d %-20s\n", u, job_count[u], total_cpu[u], (latest_end[u] == "" ? "N/A" : latest_end[u])
    }
}' | sort -k3,3rn

echo "-------------------------------------------"
echo "[*] Total Jobs Analyzed: $(echo "$RAW_DATA" | wc -l)"
