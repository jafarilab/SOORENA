# Using an Existing Digital Ocean Droplet

If your friend already has a droplet running, you can use it! No need to create a new one.

---

## Requirements Check

Ask your friend to check if their existing droplet meets these requirements:

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

## Can We Share the Droplet?

**YES!** Your app can run alongside their existing apps/websites. Here's how:

### If they're running other web apps:
- Your app runs on **port 3838**
- Their apps probably run on port 80 (HTTP) or 443 (HTTPS)
- No conflict! Both can run simultaneously

### If they're using it for something else:
- As long as it's not using port 3838, you're fine
- Check with: `sudo netstat -tulpn | grep 3838`
- If nothing shows up, port 3838 is free!

---

## Installation on Existing Droplet

### Step 1: Get Access

Your friend gives you:
1. **Droplet IP address**
2. **SSH access** (either add your SSH key or give you the password)

### Step 2: SSH In

```bash
ssh root@DROPLET_IP
```

### Step 3: Run Setup Script

Copy and run the setup script:
```bash
# From your Mac, copy the script to the droplet
scp /Users/halao/Desktop/SOORENA_2/deployment/server_setup_digitalocean.sh root@DROPLET_IP:~/

# SSH into the droplet
ssh root@DROPLET_IP

# Run the setup script
bash server_setup_digitalocean.sh
```

### Step 4: Deploy Your App

Exit SSH and run deployment from your Mac:
```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
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

**These will NOT affect their existing apps:**
- Shiny Server runs on port 3838 (separate from their apps)
- R is just a programming language (won't interfere)
- Your database is in `/srv/shiny-server/soorena/` (isolated)

---

## Accessing Both Apps

After installation:

**Their existing apps**: Still work normally
- Example: `http://DROPLET_IP/` or their domain

**Your SOORENA app**:
- Example: `http://DROPLET_IP:3838/soorena/`

Both run side-by-side with no conflicts!

---

## When You CANNOT Use an Existing Droplet

You'll need a new droplet if:

❌ **Not enough RAM**: Less than 2 GB
- Check with: `free -h`
- Solution: Ask them to resize it, or create a new one

❌ **Not enough disk space**: Less than 10 GB free
- Check with: `df -h /`
- Solution: Ask them to resize it, or create a new one

❌ **Wrong OS**: Not Ubuntu (e.g., CentOS, Debian, etc.)
- Check with: `lsb_release -a`
- Solution: Create a new droplet with Ubuntu 22.04 or 24.04

❌ **Port 3838 already in use**: Something else using port 3838
- Check with: `sudo netstat -tulpn | grep 3838`
- Solution: Either stop the conflicting service or create a new droplet

❌ **They don't want to give you access**: Understandable!
- Solution: They create a new droplet just for you

---

## Message to Send Your Friend

```
Hey! I checked and I can actually use your existing droplet if:

1. It has at least 2 GB RAM (4 GB is better)
2. It has at least 10 GB free disk space
3. It's running Ubuntu 20.04, 22.04, or 24.04
4. You're comfortable giving me SSH access

My app will run on port 3838, so it won't interfere with anything you have running.

Can you check these specs for me?
- Run: free -h (to check RAM)
- Run: df -h (to check disk space)
- Run: lsb_release -a (to check OS)

If it meets these requirements, we can use your existing droplet!
If not, we'll need to create a new one.
```

---

## Sharing Cost

If using their existing droplet:

**Good news**: No extra cost!
- Digital Ocean charges by droplet size, not by apps
- Your app shares the existing droplet's resources
- No additional monthly charge

**Optional**: You could offer to:
- Split the monthly cost with them
- Pay them a portion (e.g., $5-10/month)
- Cover any upgrade costs if they need to resize for you

---

## Best Practice: Separate Droplet vs Shared

### Use Existing Droplet If:
✅ They have plenty of spare resources (RAM/disk)
✅ Their apps are low-traffic
✅ They're comfortable sharing
✅ You want to save money

### Create New Droplet If:
✅ Their droplet is near capacity
✅ They prefer separation/isolation
✅ You want full control
✅ You need guaranteed performance

**My recommendation**: If they have a 4+ GB droplet with space, share it. If they have a 1-2 GB droplet, create a new one.

---

## Quick Decision Tree

```
Does friend have existing droplet?
│
├─ NO → Create new droplet (see INSTRUCTIONS_FOR_FRIEND.md)
│
└─ YES → Check specs:
    │
    ├─ Has 4+ GB RAM & 15+ GB free → Use existing! (Perfect)
    │
    ├─ Has 2-4 GB RAM & 10+ GB free → Use existing (will work)
    │
    └─ Less than 2 GB RAM or < 10 GB free → Create new droplet
```

---

**Bottom line**: Most likely you can use their existing droplet! Just need to verify the specs first.
