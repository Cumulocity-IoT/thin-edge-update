#!/bin/bash
set -e

# Script to manage container updates
# Usage: 
#   ./manage-update.sh check <name> <updateList>
#   ./manage-update.sh restart <name> <updateList>

LOCAL_CONF_DIR="/local-conf"

# Function to check if name exists in updateList
check_update() {
    local name="$1"
    local update_list="$2"
    
    # Parse JSON and get the first module's name
    local module_name
    module_name=$(echo "${update_list}" | jq -r '.[0].modules[0].name')
    
    if [[ "$module_name" == "$name" ]]; then
        echo "Match found: $name"
        return 0
    else
        echo "No match: $name != $module_name"
        return 1
    fi
}

# Function to restart and write config
restart_update() {
    local name="$1"
    local update_list="$2"
    
    # Parse JSON and get the first module's name and version
    local module_name
    local module_version
    module_name=$(echo "${update_list}" | jq -r '.[0].modules[0].name')
    module_version=$(echo "${update_list}" | jq -r '.[0].modules[0].version')
    
    # Verify the name matches
    if [[ "$module_name" != "$name" ]]; then
        echo "Error: Name mismatch. Expected $name but got $module_name"
        return 1
    fi
    
    # Create directory if it doesn't exist
    if [[ ! -d "$LOCAL_CONF_DIR" ]]; then
        mkdir -p "$LOCAL_CONF_DIR"
        echo "Created directory: $LOCAL_CONF_DIR"
    fi
    
    # Write to config file
    local config_file="${LOCAL_CONF_DIR}/update-${name}.cfg"
    echo "CURRENT_IMAGE=${module_version}" > "${config_file}"
    echo "Config written to ${config_file}: CURRENT_IMAGE=${module_version}"
    
    return 0
}

# Main script logic
main() {
    local cmd="$1"
    local name="$2"
    local update_list="$3"
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed."
        exit 1
    fi
    
    # Validate parameters
    if [[ -z "$cmd" ]] || [[ -z "$name" ]] || [[ -z "$update_list" ]]; then
        echo "Usage: $0 <check|restart> <name> <updateList>"
        exit 1
    fi
    
    # Validate JSON
    if ! echo "${update_list}" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON in updateList"
        exit 1
    fi
    
    case "$cmd" in
        check)
            check_update "$name" "$update_list"
            exit $?
            ;;
        restart)
            restart_update "$name" "$update_list"
            exit $?
            ;;
        *)
            echo "Error: Invalid command '$cmd'. Use 'check' or 'restart'."
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"