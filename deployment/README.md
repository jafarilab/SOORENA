# SOORENA Deployment Files

This directory contains deployment scripts and documentation for the SOORENA Shiny application.

## 🌐 Hosting Options

### Option 1: Oracle Cloud (FREE)
- **Cost**: $0 - Always Free tier
- **Setup**: More complex (firewall rules, iptables)
- **Performance**: 1 GB RAM (slower but works)
- See: [1GB_RAM_INSTRUCTIONS.md](1GB_RAM_INSTRUCTIONS.md)

### Option 2: Digital Ocean (PAID - Recommended)
- **Cost**: $12-24/month (may have free credits)
- **Setup**: Simple and straightforward
- **Performance**: Better (2-4 GB RAM recommended)
- See: [DIGITALOCEAN_INSTRUCTIONS.md](DIGITALOCEAN_INSTRUCTIONS.md)

---

## 📁 Files

### Documentation
- **`README.md`** - This file
- **`1GB_RAM_INSTRUCTIONS.md`** - Oracle Cloud setup guide (1GB RAM instance)
- **`DIGITALOCEAN_INSTRUCTIONS.md`** - Digital Ocean setup guide

### Oracle Cloud Scripts
- **`server_setup_1GB.sh`** - Oracle Cloud server configuration
- **`deploy_to_oracle.sh`** - Oracle Cloud deployment

### Digital Ocean Scripts
- **`server_setup_digitalocean.sh`** - Digital Ocean server configuration
- **`deploy_to_digitalocean.sh`** - Digital Ocean deployment

### Shared Scripts
- **`update_app.sh`** - Quick update for app.R changes only

## 🚀 Deployment Instructions

### Initial Setup

1. **Configure server** (SSH into Oracle Cloud VM):
   ```bash
   bash server_setup_1GB.sh
   ```

2. **Deploy application** (run locally):
   ```bash
   ./deploy_to_oracle.sh
   ```

### Updates

For app.R changes only:
```bash
./update_app.sh
```

## 🛠️ Scripts Usage

### server_setup.sh
**Purpose**: Install R, Shiny Server, and all dependencies on your Oracle Cloud VM

**Run on**: The Oracle Cloud VM (via SSH)

**Usage**:
```bash
# SSH into your VM first
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_PUBLIC_IP

# Then run the setup script
bash server_setup.sh
```

**What it does**:
- Updates Ubuntu
- Installs R and system dependencies
- Installs Shiny Server
- Installs required R packages (shiny, DT, plotly, etc.)
- Configures firewall
- Creates app directory

**Run once**: You only need to run this once when setting up a new server.

---

### deploy_to_oracle.sh
**Purpose**: Deploy your complete SOORENA app to the server

**Run on**: Your local machine (Mac)

**Usage**:
```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
./deploy_to_oracle.sh
```

**What it does**:
- Tests SSH connection
- Creates app directory structure
- Uploads app.R
- Uploads database (6.1 GB) - **takes 5-15 minutes**
- Uploads images and assets
- Sets correct permissions
- Restarts Shiny Server

**When to use**:
- First deployment
- Major updates that include database changes
- When you've updated images or other assets

---

### update_app.sh
**Purpose**: Quick update when you've only changed app.R

**Run on**: Your local machine (Mac)

**Usage**:
```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
./update_app.sh
```

**What it does**:
- Uploads only app.R (fast!)
- Restarts Shiny Server

**When to use**:
- You fixed a UI bug
- You updated colors or styling
- You changed filters or query logic
- Any change to app.R only (no database/images)

**Advantage**: Takes seconds instead of 15+ minutes!

---

## 💰 Cost

**Completely FREE** with Oracle Cloud Always Free tier.

Your setup uses:
- **Compute**: 2 OCPUs, 12 GB RAM (Ampere A1 Flex)
- **Storage**: ~56 GB (OS + database + app)
- **Bandwidth**: Minimal (research database, not high traffic)

**All within the Always Free limits. No hidden costs.**

---

## 🎯 Typical Workflow

### Initial Deployment
1. Create Oracle Cloud account
2. Create VM instance
3. SSH into VM: `ssh -i ~/Downloads/ssh-key-*.key ubuntu@IP`
4. Run: `bash server_setup.sh` (on server)
5. Exit SSH
6. Run: `./deploy_to_oracle.sh` (on local machine)
7. Access: `http://YOUR_IP:3838/soorena/`

### After Making Changes to app.R
1. Edit `shiny_app/app.R` on your local machine
2. Run: `./update_app.sh`
3. Refresh browser

### After Updating Database
1. Rebuild database: `python scripts/python/data_processing/create_sqlite_db.py`
2. Run: `./deploy_to_oracle.sh` (uploads new database)
3. Refresh browser

---

## 📊 Server Specifications

Your Oracle Cloud VM:
- **OS**: Ubuntu 22.04 LTS
- **CPU**: 2 Ampere A1 cores (ARM64)
- **RAM**: 12 GB
- **Storage**: 50 GB boot volume
- **Network**: Public IPv4 address
- **Cost**: FREE forever

Perfect for:
- Research databases
- Shiny apps
- Small to medium traffic
- 24/7 availability

---

## 🔐 Security Notes

1. **SSH Key**: Keep your private key secure
   - Don't commit it to git
   - Don't share it
   - Store it safely (e.g., `~/.ssh/`)

2. **Firewall**: Only ports 22 (SSH) and 3838 (Shiny) are open

3. **Updates**: Regularly update your server
   ```bash
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP
   sudo apt update && sudo apt upgrade -y
   ```

4. **Access Control**: Consider IP whitelisting for sensitive data

---

## 🐛 Troubleshooting

### App won't load
1. Check Shiny Server status:
   ```bash
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP "sudo systemctl status shiny-server"
   ```

2. Check logs:
   ```bash
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP "sudo tail -f /var/log/shiny-server.log"
   ```

3. Verify database exists:
   ```bash
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP "ls -lh /srv/shiny-server/soorena/data/"
   ```

### Can't SSH into server
1. Verify IP address is correct
2. Check SSH key path
3. Verify key permissions: `chmod 400 ~/Downloads/ssh-key-*.key`

### Port 3838 not accessible
1. Check Oracle Cloud Security List (is port 3838 open?)
2. Check Ubuntu firewall: `sudo ufw status`

---

## 📞 Need Help?

1. Check the detailed guide: [oracle_cloud_setup.md](oracle_cloud_setup.md)
2. Check server logs for errors
3. Verify all prerequisites are met
4. Review the troubleshooting section above

---

## ✅ Pre-Deployment Checklist

Before running deployment scripts, verify:

- [ ] Database exists: `shiny_app/data/predictions.db`
- [ ] Database is up to date (run `create_sqlite_db.py` if needed)
- [ ] Team photos exist: `shiny_app/www/images/team/*.jpg`
- [ ] app.R has no syntax errors
- [ ] You have Oracle Cloud account
- [ ] You have VM created with Ubuntu
- [ ] You have SSH private key downloaded
- [ ] Port 3838 is open in Security List
- [ ] Good internet connection (6GB upload)

---

## 🎉 Success Indicators

Your deployment is successful when:
- ✓ You can access `http://YOUR_IP:3838/soorena/` in browser
- ✓ Dashboard loads with all tabs working
- ✓ Data Explorer shows records
- ✓ Statistics charts display correctly
- ✓ Filters work properly
- ✓ Team photos appear on About Us page
- ✓ No errors in browser console
- ✓ No errors in Shiny Server logs

---

**Happy Deploying! 🚀**
