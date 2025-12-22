# SOORENA Deployment on Digital Ocean

## Quick Setup Guide

Digital Ocean is simpler than Oracle Cloud - no complex firewall rules, straightforward setup.

---

## Step 1: Create a Droplet

1. Go to [Digital Ocean](https://www.digitalocean.com/)
2. Click **Create** → **Droplets**
3. Choose configuration:
   - **Image**: Ubuntu 22.04 or 24.04 LTS
   - **Droplet Size**:
     - **Recommended**: Basic Plan - 4 GB RAM / 2 vCPUs ($24/month)
     - **Minimum**: 2 GB RAM / 1 vCPU ($12/month)
   - **Datacenter**: Choose closest to you (e.g., Toronto, New York)
   - **Authentication**: SSH Key (recommended) or Password
   - **Hostname**: `soorena-app`

4. Click **Create Droplet**

---

## Step 2: Get Your Droplet IP

Once created, you'll see your droplet's **Public IPv4 address**. Copy it!

Example: `164.92.XXX.XXX`

---

## Step 3: SSH into Your Droplet

### If using SSH key:
```bash
ssh root@YOUR_DROPLET_IP
```

### If using password:
```bash
ssh root@YOUR_DROPLET_IP
# Enter the password sent to your email
```

When asked "Are you sure you want to continue connecting?", type `yes`.

---

## Step 4: Copy and Run Setup Script

Open a **NEW Terminal window** (keep SSH session open):

```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
scp server_setup_digitalocean.sh root@YOUR_DROPLET_IP:~/
```

Then in your **SSH session**:

```bash
bash server_setup_digitalocean.sh
```

When prompted, type `y` to continue.

⏱️ **Wait 10-15 minutes** for installation to complete.

---

## Step 5: Deploy Your App

Exit SSH:
```bash
exit
```

On your **Mac**:

```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
./deploy_to_digitalocean.sh
```

Enter:
- Your droplet IP
- Your SSH key path (e.g., `~/.ssh/id_rsa`)

⏱️ **Database upload takes 5-15 minutes**

---

## Step 6: Access Your App

Open in browser:
```
http://YOUR_DROPLET_IP:3838/soorena/
```

---

## Digital Ocean vs Oracle Cloud

### Digital Ocean Advantages:
✅ Simpler setup (no complex firewall rules)
✅ Better performance (faster CPUs)
✅ Faster network speeds
✅ Root access by default
✅ Easy to resize
✅ Better documentation
✅ Predictable pricing

### Digital Ocean Disadvantages:
❌ Not free (but your friend's account may have credits)
❌ Costs $12-24/month after credits

---

## Recommended Droplet Sizes

### For 6.1 GB Database:

**Minimum (works but slower):**
- 2 GB RAM / 1 vCPU
- $12/month
- Good for 1-5 concurrent users

**Recommended (smooth performance):**
- 4 GB RAM / 2 vCPUs
- $24/month
- Good for 5-20 concurrent users

**Optimal (best experience):**
- 8 GB RAM / 4 vCPUs
- $48/month
- Good for 20+ concurrent users

---

## Troubleshooting

### Can't SSH:
```bash
# If using password, check your email for credentials
# If using SSH key, make sure it's added to droplet during creation
```

### Port 3838 not accessible:
Digital Ocean's firewall is simpler - usually just works. If not:
```bash
ssh root@YOUR_DROPLET_IP
sudo ufw status
sudo ufw allow 3838/tcp
```

### App won't start:
```bash
ssh root@YOUR_DROPLET_IP
sudo tail -100 /var/log/shiny-server.log
```

---

## Managing Your Droplet

### Restart Shiny Server:
```bash
ssh root@YOUR_DROPLET_IP
systemctl restart shiny-server
```

### Check memory usage:
```bash
ssh root@YOUR_DROPLET_IP
free -h
htop
```

### Update system:
```bash
ssh root@YOUR_DROPLET_IP
apt update && apt upgrade -y
```

---

## Cost Estimates

**Monthly costs:**
- 2 GB RAM: $12/month
- 4 GB RAM: $24/month
- 8 GB RAM: $48/month

**Bandwidth:** 2-4 TB included (plenty for research database)

**Your friend may have:**
- Free credits ($100-200) for new accounts
- Student credits (if in school)
- Promo codes

---

## Next Steps After Deployment

1. ✅ Test the app thoroughly
2. ✅ Consider setting up a domain name (optional)
3. ✅ Set up SSL/HTTPS if handling sensitive data (optional)
4. ✅ Monitor usage to choose right droplet size
5. ✅ Set up automated backups (Digital Ocean offers this)

---

## Quick Command Reference

```bash
# SSH into droplet
ssh root@YOUR_DROPLET_IP

# Check Shiny Server status
systemctl status shiny-server

# View logs
tail -f /var/log/shiny-server.log

# Restart Shiny Server
systemctl restart shiny-server

# Check disk space
df -h

# Check memory
free -h
```

---

**Ready to deploy! 🚀**
