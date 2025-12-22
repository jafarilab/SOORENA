# Using Existing Cloud Infrastructure

This guide explains how to deploy SOORENA on existing cloud infrastructure.

---

## Requirements Check

Verify your existing infrastructure meets these requirements:

### Minimum Requirements:
- ✅ **OS**: Ubuntu 20.04, 22.04, or 24.04 (preferred)
- ✅ **RAM**: At least 2 GB (4 GB recommended)
- ✅ **Disk Space**: At least 10 GB free (for 6.1 GB database + OS)
- ✅ **Access**: Root or sudo access

### How to Check:

**Check OS version:**
```bash
lsb_release -a
```
Should show: Ubuntu 20.04, 22.04, or 24.04

**Check RAM:**
```bash
free -h
```
Should show at least 2 GB total

**Check free disk space:**
```bash
df -h
```
Should show at least 10 GB available

---

## Shared Infrastructure Compatibility

SOORENA can run alongside existing applications. Here's how:

### If running other web applications:
- SOORENA runs on **port 3838**
- Other apps typically run on port 80 (HTTP) or 443 (HTTPS)
- No conflict - applications can run simultaneously

### Port availability check:
- Verify port 3838 is available
- Check with: `sudo netstat -tulpn | grep 3838`
- If no output, port 3838 is available

---

## Installation on Existing Infrastructure

### Step 1: Obtain Access

Required information:
1. **Instance IP address**
2. **SSH access** (SSH key or password)

### Step 2: Connect via SSH

```bash
ssh root@INSTANCE_IP
```

### Step 3: Run Setup Script

Copy and run the setup script:
```bash
# From your local machine, copy the script
scp /path/to/SOORENA_2/deployment/server_setup_digitalocean.sh root@INSTANCE_IP:~/

# SSH into the instance
ssh root@INSTANCE_IP

# Run the setup script
bash server_setup_digitalocean.sh
```

### Step 4: Deploy Application

Exit SSH and run deployment from local machine:
```bash
cd /path/to/SOORENA_2/deployment
./deploy_to_digitalocean.sh
```

---

## What Gets Installed?

The setup script will install:
- R (programming language)
- Shiny Server (web server for R apps)
- Required R packages
- Your app files and database

**Total disk space used**: ~8-10 GB

**Impact on existing applications:**
- Shiny Server runs on port 3838 (separate port)
- R installation does not interfere with existing software
- Database stored in `/srv/shiny-server/soorena/` (isolated directory)

---

## Accessing Applications

After installation:

**Existing applications**: Continue functioning normally
- Example: `http://INSTANCE_IP/` or configured domain

**SOORENA application**:
- Example: `http://INSTANCE_IP:3838/soorena/`

Both run concurrently without conflicts.

---

## When New Infrastructure is Required

Create new infrastructure if:

**Insufficient RAM**: Less than 2 GB
- Check with: `free -h`
- Solution: Resize instance or create new infrastructure

**Insufficient disk space**: Less than 10 GB free
- Check with: `df -h /`
- Solution: Resize storage or create new infrastructure

**Incompatible OS**: Not Ubuntu (e.g., CentOS, Debian)
- Check with: `lsb_release -a`
- Solution: Create new instance with Ubuntu 22.04 or 24.04

**Port conflict**: Port 3838 already in use
- Check with: `sudo netstat -tulpn | grep 3838`
- Solution: Stop conflicting service or create new infrastructure

**Access restrictions**: Cannot obtain necessary access
- Solution: Create dedicated infrastructure

---

## Infrastructure Verification

To verify existing infrastructure compatibility, run:

```bash
# Check RAM
free -h

# Check disk space
df -h

# Check OS version
lsb_release -a

# Check port availability
sudo netstat -tulpn | grep 3838
```

If all requirements are met, proceed with installation. Otherwise, create new infrastructure.

---

## Resource Sharing

When using existing infrastructure:

- Cloud providers charge by instance size, not by applications
- SOORENA shares existing instance resources
- No additional infrastructure charges

Resource requirements:
- ~8-10 GB disk space
- Shared RAM and CPU resources
- Minimal network bandwidth

---

## Infrastructure Decision Matrix

### Use Existing Infrastructure If:
- Adequate spare resources (RAM/disk)
- Low-traffic applications
- Shared access is acceptable
- Resource optimization is desired

### Create New Infrastructure If:
- Instance near capacity
- Isolation preferred
- Full control required
- Guaranteed performance needed

**Technical Recommendation**:
- 4+ GB instance with adequate free space: Suitable for sharing
- 1-2 GB instance: Create dedicated infrastructure

---

## Decision Tree

```
Existing infrastructure available?
│
├─ NO → Create new infrastructure (see DEPLOYMENT_GUIDE.md)
│
└─ YES → Check specifications:
    │
    ├─ 4+ GB RAM & 15+ GB free → Use existing (Optimal)
    │
    ├─ 2-4 GB RAM & 10+ GB free → Use existing (Acceptable)
    │
    └─ Less than 2 GB RAM or < 10 GB free → Create new infrastructure
```

---

Verify specifications before proceeding with installation.
