#!/bin/bash

# Admin Training: LDAP to Slurm Synchronization Simulation
# This script simulates how an admin would automate the onboarding
# of users from an external directory (like LDAP/AD) into Slurm.

CONTROLLER="slurmctld"
PROJECT_NAME="bio_research"
MOCK_LDAP_FILE="/tmp/mock_ldap_users.txt"

echo -e "\n\033[1;34m============================================================\033[0m"
echo -e "\033[1;36m SIMULATING LDAP SYNC TO SLURM \033[0m"
echo -e "\033[1;34m============================================================\033[0m"

# 1. Create Mock LDAP Data
# Format: username:group:full_name
echo "alice:bio_group:Alice Smith" > $MOCK_LDAP_FILE
echo "bob:bio_group:Bob Jones" >> $MOCK_LDAP_FILE
echo "charlie:chem_group:Charlie Brown" >> $MOCK_LDAP_FILE

echo "[*] Mock LDAP Database created at $MOCK_LDAP_FILE"
cat $MOCK_LDAP_FILE
echo "------------------------------------------------------------"

# 2. Setup Slurm Account
echo "[*] Ensuring Slurm Account '$PROJECT_NAME' exists..."
docker exec $CONTROLLER sacctmgr -i add account $PROJECT_NAME Description="Bioprocessing Research" &> /dev/null

# 3. The Sync Script logic
echo "[*] Running Sync Logic: Adding all 'bio_group' members to Slurm '$PROJECT_NAME'..."

# In a real environment, you might use 'getent group' instead of reading a file
while IFS=: read -r username group fullname; do
    if [ "$group" == "bio_group" ]; then
        echo "    -> Processing user: $username ($fullname)"
        
        # Step A: Ensure OS user exists (Simulating SSSD/LDAP resolution)
        # Note: In real LDAP, this step isn't needed as SSSD handles it, 
        # but for Docker we need to create the entry.
        docker exec $CONTROLLER id $username &> /dev/null
        if [ $? -ne 0 ]; then
            echo "       [OS] Creating local mock entry for $username..."
            docker exec $CONTROLLER useradd -m $username &> /dev/null
        fi

        # Step B: Add to Slurm
        # We use -i for immediate/non-interactive
        docker exec $CONTROLLER sacctmgr -i add user $username account=$PROJECT_NAME &> /dev/null
        echo "       [Slurm] Added to $PROJECT_NAME"
    else
        echo "    -> Skipping $username (In group $group, not $PROJECT_NAME)"
    fi
done < $MOCK_LDAP_FILE

echo "------------------------------------------------------------"
echo "[*] Verification: Current Users in '$PROJECT_NAME':"
docker exec $CONTROLLER sacctmgr show assoc account=$PROJECT_NAME format=Account,User,Partition

echo -e "\n\033[1;32mDONE:\033[0m Sync completed. Only relevant LDAP users were imported."
echo "Interview Tip: Mention that real syncs often use 'crontab' to run every hour."
