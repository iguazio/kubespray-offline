#!/bin/bash
set -e
# Function to display usage information
usage() {
    echo "Usage: $0 [check|backup|renew]"
    exit 1
}

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    usage
fi

# Validate the argument
case $1 in
    check|backup|renew)
        # Run ansible with the provided argument
        . venv/bin/activate && \
        ansible-playbook -i inventory/igz/igz_inventory.ini igz_certs.yml --become --extra-vars=@igz_override.yml --extra-vars "do=$1" && \
        deactivate
        ;;
    *)
        # Invalid argument, display usage information
        usage
        ;;
esac
