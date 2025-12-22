# SOORENA Deployment on 1 GB RAM Instance

## Your Instance: VM.Standard.E2.1.Micro

You're using a 1 GB RAM instance, which requires special configuration for your 6.1 GB database.

---

## Step-by-Step Setup

### Step 1: Set Up SSH Key Permissions

On your **Mac**, open Terminal and run:

```bash
cd ~/Downloads
chmod 400 ssh-key-*.key
```

Replace `ssh-key-*.key` with your actual SSH key filename.

---

### Step 2: Connect to Your Server

```bash
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_PUBLIC_IP
```


Replace:
- `ssh-key-*.key` with your key filename
- `YOUR_PUBLIC_IP` with your instance's public IP

When asked "Are you sure you want to continue connecting?", type `yes` and press Enter.

---

### Step 3: Copy Setup Script to Server

Open a **NEW Terminal window** (keep the SSH session open):

```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
scp -i ~/Downloads/ssh-key-*.key server_setup_1GB.sh ubuntu@YOUR_PUBLIC_IP:~/
```

---

### Step 4: Run Setup Script

Go back to your **SSH session** (first Terminal window):

```bash
bash server_setup_1GB.sh
```

When prompted "Continue? (y/n):", type `y` and press Enter.

---

### Step 5: Wait for Installation (15-20 minutes)

The script will:
1. ✓ Create 4 GB swap space (virtual memory)
2. ✓ Update system
3. ✓ Install R
4. ✓ Install system dependencies
5. ✓ Install Shiny Server
6. ✓ Install R packages (one at a time - slow but safe)
7. ✓ Configure firewall
8. ✓ Optimize Shiny Server for low memory

Note: This process takes 15-20 minutes on 1 GB RAM.

---

### Step 6: Exit SSH

When setup completes, exit:

```bash
exit
```

---

### Step 7: Deploy Your App

On your **Mac**:

```bash
cd /Users/halao/Desktop/SOORENA_2/deployment
./deploy_to_oracle.sh
```

Enter your IP and SSH key path when prompted.

**Note:** Database upload will take 10-20 minutes (6.1 GB file)

---

## Expected Performance with 1 GB RAM

### What to Expect:

- **Functionality** - App will function correctly
- **Performance** - First load takes 30-60 seconds
- **Concurrency** - Best for 1-3 users at a time
- **Stability** - Once loaded, queries are reasonably fast

### Optimizations Applied:

- 4 GB swap space added
- Shiny Server configured for low memory
- R packages installed carefully to avoid crashes
- Database uses SQLite (very memory efficient)

---

## After Deployment

Your app will be at:
```
http://YOUR_IP:3838/soorena/
```

### First Access:
- May take 30-60 seconds to load
- Be patient, don't refresh!
- Subsequent loads will be faster

### Monitor Performance:

```bash
# Check memory usage
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP
free -h
htop
```

---

## Troubleshooting

### App won't start:

```bash
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP
sudo tail -f /var/log/shiny-server.log
```

### Out of memory errors:

```bash
# Verify swap is active
free -h

# Should show 4G swap space
```

### Restart Shiny Server:

```bash
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_IP
sudo systemctl restart shiny-server
```

---

## Future: Upgrade to Ampere

Keep trying for **VM.Standard.A1.Flex** in Toronto:
- Try early morning (6-8 AM EST)
- Try late night (11 PM - 2 AM EST)
- Try weekends

When you get Ampere:
1. Create new instance with 2 OCPUs / 12 GB RAM
2. Run regular `server_setup.sh` (not the 1GB version)
3. Deploy app to new instance
4. Delete old E2.1.Micro instance

---

## Next Steps

1. Configure firewall (port 3838) in Oracle Cloud Console
2. SSH into server
3. Run `server_setup_1GB.sh`
4. Deploy app with `deploy_to_oracle.sh`
5. Access your app
