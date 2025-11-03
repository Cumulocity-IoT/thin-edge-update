#!/bin/bash
set -e

# Script to initiate update by writing timestamp to config file
# Usage: ./manage-restart.sh

LOCAL_CONF_FILE="/local-conf/update.cfg"

# Function to initiate update
initiate_update() {
    local timestamp
    timestamp=$(date +%s)
    
    # Create directory if it doesn't exist
    local dir
    dir=$(dirname "${LOCAL_CONF_FILE}")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "Created directory: $dir"
    fi
    
    echo "UPDATE_INITIATED=${timestamp}" > "${LOCAL_CONF_FILE}"
    echo "Update initiated: UPDATE_INITIATED=${timestamp} written to ${LOCAL_CONF_FILE}"
}

# Execute the function
initiate_update