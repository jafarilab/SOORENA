# SOORENA Deployment Guide for Cloud Infrastructure

This guide provides instructions for deploying SOORENA on cloud infrastructure.

## Overview

SOORENA is a Shiny dashboard for analyzing protein research data. It includes a 6.1 GB database with 3.37 million records and requires appropriate cloud infrastructure for hosting.

## Infrastructure Options

### Using Existing Infrastructure

If you have an existing server or cloud instance, verify it meets these requirements:

**Minimum Requirements:**
- At least 2 GB RAM (4 GB recommended)
- At least 10 GB free disk space
- Ubuntu 20.04, 22.04, or 24.04

**Compatibility Check:**

Check OS version:
```bash
lsb_release -a
```

Check RAM:
```bash
free -h
```

Check free disk space:
```bash
df -h
```

If your infrastructure meets these requirements, see [USING_EXISTING_DROPLET.md](USING_EXISTING_DROPLET.md) for deployment instructions.

If not, create new infrastructure following the specifications below.

---

## Creating New Infrastructure

### DigitalOcean Deployment

**Step 1: Create a Droplet**

1. Log into DigitalOcean
2. Click Create > Droplets

**Step 2: Configure Settings**

**Image:**
- Ubuntu 22.04 or 24.04 (LTS) x64

**Droplet Size Options:**

**Minimum Configuration:**
- Type: Basic
- CPU: Regular
- Size: 2 GB RAM / 1 vCPU / 50 GB SSD

**Recommended Configuration:**
- Type: Basic
- CPU: Regular
- Size: 4 GB RAM / 2 vCPUs / 80 GB SSD

**Optimal Configuration:**
- Type: Basic
- CPU: Regular
- Size: 8 GB RAM / 4 vCPUs / 160 GB SSD

**Datacenter Region:**
- Choose the region closest to your primary users

**Authentication:**

Option A - SSH Key (Recommended):
- Click "New SSH Key"
- Add your public SSH key
- Give it a descriptive name

Option B - Password:
- Use password authentication
- Save the root password provided

**Hostname:**
- Name: `soorena-app`

**Step 3: Access Information**

After creation, note:
1. The droplet's public IP address
2. Authentication credentials (SSH key or password)

**Step 4: Deploy Application**

SSH into the droplet:
```bash
ssh root@YOUR_DROPLET_IP
```

Copy and run setup script:
```bash
# From your local machine
cd deployment
scp server_setup_digitalocean.sh root@YOUR_DROPLET_IP:~/

# On the droplet
bash server_setup_digitalocean.sh
```

Deploy the application:
```bash
cd deployment
./deploy_to_digitalocean.sh
```

Access the application at: `http://YOUR_DROPLET_IP:3838/soorena/`

---

## Resource Specifications

### Minimum Configuration
- **RAM**: 2 GB
- **Performance**: Slower initial load (30-60 seconds)
- **Use Case**: Testing and light use

### Recommended Configuration
- **RAM**: 4 GB
- **Performance**: Smooth operation (10-20 second load)
- **Use Case**: Regular use, small team

### Optimal Configuration
- **RAM**: 8 GB
- **Performance**: Fast operation (instant load)
- **Use Case**: Heavy use, larger team

---

## Bandwidth Requirements

All configurations include adequate bandwidth:
- 2-4 TB of bandwidth included
- Research database with moderate traffic
- Sufficient for typical academic use

---

## Deployment Workflow

### Initial Deployment
1. Create infrastructure instance
2. Configure authentication
3. SSH into instance
4. Run setup script (15 minutes, automated)
5. Deploy application (10 minutes, automated)
6. Access application via browser

### Application Updates
For application code changes only:
```bash
./update_app.sh
```

### Database Updates
For database updates:
```bash
./deploy_to_digitalocean.sh
```

---

## Security Considerations

**SSH Key Management:**
- Keep private keys secure
- Do not commit keys to version control
- Store keys in secure location (e.g., `~/.ssh/`)

**Access Control:**
- Only ports 22 (SSH) and 3838 (Shiny) are exposed
- Consider IP whitelisting for sensitive data
- Regularly update server packages

**Regular Maintenance:**
```bash
ssh root@YOUR_IP
sudo apt update && sudo apt upgrade -y
```

---

## Troubleshooting

### Cannot SSH into instance
1. Verify IP address is correct
2. Check SSH key path
3. Verify key permissions: `chmod 400 ~/path/to/key`

### Application not loading
1. Check Shiny Server status:
   ```bash
   ssh root@YOUR_IP "sudo systemctl status shiny-server"
   ```

2. Check logs:
   ```bash
   ssh root@YOUR_IP "sudo tail -f /var/log/shiny-server.log"
   ```

3. Verify database exists:
   ```bash
   ssh root@YOUR_IP "ls -lh /srv/shiny-server/soorena/data/"
   ```

### Performance Issues
- Verify adequate RAM allocation
- Check concurrent user load
- Consider upgrading to higher-tier configuration

---

## Additional Resources

- [USING_EXISTING_DROPLET.md](USING_EXISTING_DROPLET.md) - Using existing infrastructure
- [1GB_RAM_INSTRUCTIONS.md](1GB_RAM_INSTRUCTIONS.md) - Low-resource deployment
- [README.md](README.md) - Deployment scripts overview

---

## Support

For technical issues:
1. Check application logs
2. Verify infrastructure specifications
3. Review troubleshooting section
4. Consult deployment documentation
