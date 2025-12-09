# GCP VM Configuration Automation

This automation script configures NFS mounts and GitLab user settings across all VMs in your GCP project.

## What it Does

The automation performs the following tasks on each VM:

1. **NFS Configuration**
   - Installs `nfs-common` package
   - Creates `/mnt/files` mount point
   - Configures NFS mount to `x.x.x.x:/filestore_nfs_2`
   - Adds entry to `/etc/fstab` for persistent mounting

2. **GitLab User Setup**
   - Configures SSH authorized keys for `gitlab` user
   - Copies deployment keys from NFS mount
   - Sets proper permissions on `.ssh` directory
   - Adds `gitlab` user to `www-data` group

## Prerequisites

- gcloud CLI installed and configured
- Authentication for the `nelc-preprod` project
- IAP (Identity-Aware Proxy) access to VMs
- Bash shell (Linux, macOS, or WSL on Windows)

## Files

- `configure-vm.sh` - The configuration script executed on each VM
- `run-on-all-vms.sh` - Main automation script that runs on all VMs
- `logs/` - Directory containing execution logs for each VM

## Usage

### 1. Review Configuration

Before running, verify the settings in `run-on-all-vms.sh`:

```bash
PROJECT_ID=""
ZONE=""
```

### 2. Make Scripts Executable

```bash
chmod +x configure-vm.sh run-on-all-vms.sh
```

### 3. Run the Automation

```bash
./run-on-all-vms.sh
```

### 4. Optional: Run on Specific Zone

To target VMs in a specific zone only, modify the script or use this approach:

```bash
# Edit run-on-all-vms.sh and update the gcloud command:
gcloud compute instances list \
    --project="${PROJECT_ID}" \
    --zones="${ZONE}" \
    --format="value(name,zone)"
```

### 5. Optional: Dry Run

To test without making changes, you can add `echo` before the gcloud commands in `run-on-all-vms.sh`:

```bash
echo gcloud compute scp ...
echo gcloud compute ssh ...
```

## Output

The script provides:

- **Console Output**: Real-time progress with color-coded status
  - 🟢 Green: Success
  - 🔴 Red: Failures
  - 🟡 Yellow: Skipped/Warnings

- **Log Files**: 
  - `logs/automation.log` - Overall automation log
  - `logs/<vm-name>.log` - Individual VM execution logs

## Summary Report

At the end, you'll see a summary like:

```
================================================
Configuration Automation Summary
================================================
Total VMs:      10
Successful:     8
Failed:         1
Skipped:        1
================================================
```

## Troubleshooting

### Error: "Permission denied"

Ensure you have the necessary IAM permissions:
- `compute.instances.list`
- `compute.instances.get`
- `iap.tunnelInstances.accessViaIAP`

### Error: "VM not found"

Verify the project ID and zone are correct in the script.

### Configuration Failed on a VM

Check the individual VM log in `logs/<vm-name>.log` for detailed error messages.

### Script Hangs

Some VMs might have connectivity issues. You can set a timeout by modifying the gcloud ssh command:

```bash
# Add --ssh-flag="-o ConnectTimeout=30"
gcloud compute ssh "${VM_NAME}" \
    --ssh-flag="-o ConnectTimeout=30" \
    ...
```

## Customization

### Run on Specific VMs Only

Create a file `vms.txt` with VM names (one per line) and modify the script:

```bash
# Replace the gcloud instances list command with:
VMS=$(cat vms.txt | while read vm; do 
    echo "${vm}\t${ZONE}"
done)
```

### Skip Already Configured VMs

Add a check in `configure-vm.sh`:

```bash
# At the beginning of configure-vm.sh
if grep -q "10.211.189.26:/filestore_nfs_2" /etc/fstab; then
    echo "Already configured, skipping..."
    exit 0
fi
```

## Safety Notes

> [!CAUTION]
> This script makes system-level changes including:
> - Installing packages
> - Modifying `/etc/fstab`
> - Changing file permissions
> - Adding mount points

> [!IMPORTANT]
> Always test on a single VM first before running on all VMs:
> ```bash
> VM_NAME="your-test-vm"
> ZONE="me-central2-a"
> gcloud compute scp ./configure-vm.sh ${VM_NAME}:/tmp/ \
>     --zone=${ZONE} --project=nelc-preprod --tunnel-through-iap
> gcloud compute ssh ${VM_NAME} --zone=${ZONE} \
>     --project=nelc-preprod --tunnel-through-iap \
>     --command="chmod +x /tmp/configure-vm.sh && sudo /tmp/configure-vm.sh"
> ```
