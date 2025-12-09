#!/bin/bash
# Automation script to run configuration on all VMs in a GCP project

# Configuration
PROJECT_ID=""
# Note: This script targets ALL zones in the project (me-central2-a, me-central2-b, me-central2-c)
SCRIPT_PATH="./configure-vm.sh"
LOG_DIR="./logs"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "${LOG_DIR}"

# Function to log messages
log() {
    echo -e "${1}" | tee -a "${LOG_DIR}/automation.log"
}

# Check if script file exists
if [ ! -f "${SCRIPT_PATH}" ]; then
    log "${RED}Error: Configuration script not found at ${SCRIPT_PATH}${NC}"
    exit 1
fi

log "${GREEN}Starting VM configuration automation for project: ${PROJECT_ID}${NC}"
log "Log directory: ${LOG_DIR}"
log "Configuration script: ${SCRIPT_PATH}"
log "================================================"

# Get list of all VMs in the project (from ALL zones: me-central2-a, me-central2-b, me-central2-c)
log "${YELLOW}Fetching list of VMs from all zones...${NC}"
VMS=$(gcloud compute instances list \
    --project="${PROJECT_ID}" \
    --format="value(name,zone)" 2>&1)

if [ $? -ne 0 ]; then
    log "${RED}Error fetching VMs: ${VMS}${NC}"
    exit 1
fi

# Count total VMs
TOTAL_VMS=$(echo "${VMS}" | wc -l)
log "${GREEN}Found ${TOTAL_VMS} VM(s) in project ${PROJECT_ID}${NC}"
log "================================================"

# Initialize counters
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Process each VM
while IFS=$'\t' read -r VM_NAME VM_ZONE; do
    # Skip empty lines
    if [ -z "${VM_NAME}" ]; then
        continue
    fi
    
    log "\n${YELLOW}Processing VM: ${VM_NAME} (Zone: ${VM_ZONE})${NC}"
    LOG_FILE="${LOG_DIR}/${VM_NAME}.log"
    
    # Check if VM is running
    VM_STATUS=$(gcloud compute instances describe "${VM_NAME}" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --format="value(status)" 2>&1)
    
    if [ "${VM_STATUS}" != "RUNNING" ]; then
        log "${YELLOW}  ⚠ VM is not running (Status: ${VM_STATUS}). Skipping...${NC}"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    # Copy script to VM
    log "  📤 Copying configuration script to VM..."
    if gcloud compute scp "${SCRIPT_PATH}" "${VM_NAME}:/tmp/configure-vm.sh" \
        --zone="${VM_ZONE}" \
        --project="${PROJECT_ID}" \
        --tunnel-through-iap \
        --quiet < /dev/null > "${LOG_FILE}" 2>&1; then
        
        # Execute script on VM
        log "  🔧 Executing configuration script..."
        if gcloud compute ssh "${VM_NAME}" \
            --zone="${VM_ZONE}" \
            --project="${PROJECT_ID}" \
            --tunnel-through-iap \
            --command="chmod +x /tmp/configure-vm.sh && sudo /tmp/configure-vm.sh" \
            --quiet < /dev/null >> "${LOG_FILE}" 2>&1; then
            
            log "  ${GREEN}✓ Successfully configured ${VM_NAME}${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log "  ${RED}✗ Failed to execute script on ${VM_NAME}${NC}"
            log "  ${RED}  See log: ${LOG_FILE}${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        log "  ${RED}✗ Failed to copy script to ${VM_NAME}${NC}"
        log "  ${RED}  See log: ${LOG_FILE}${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
done < <(echo "${VMS}")

# Print summary
log "\n================================================"
log "${GREEN}Configuration Automation Summary${NC}"
log "================================================"
log "Total VMs:      ${TOTAL_VMS}"
log "${GREEN}Successful:     ${SUCCESS_COUNT}${NC}"
log "${RED}Failed:         ${FAIL_COUNT}${NC}"
log "${YELLOW}Skipped:        ${SKIP_COUNT}${NC}"
log "================================================"

# Exit with appropriate code
if [ ${FAIL_COUNT} -gt 0 ]; then
    log "${RED}Some VMs failed to configure. Check logs in ${LOG_DIR}${NC}"
    exit 1
else
    log "${GREEN}All VMs configured successfully!${NC}"
    exit 0
fi
