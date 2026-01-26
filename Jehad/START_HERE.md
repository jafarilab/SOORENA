# SOORENA Deployment for University of Helsinki Server

Welcome Jehad! This folder contains everything you need to deploy SOORENA.


---

## What's in This Folder

```
Jehad/
├── START_HERE.md                    ← You are here! Read this first
├── DETAILED_GUIDE.md                ← Complete step-by-step instructions
├── scripts/
│   ├── helsinki_server_setup.sh     ← Run on server (installs software)
│   └── helsinki_deploy_app.sh       ← Run on your computer (uploads app)
└── configs/
    ├── nginx_helsinki.conf          ← Nginx configuration
    └── shiny-server_helsinki.conf   ← Shiny Server configuration
```

---

## BEFORE YOU START - What You Need from Helsinki IT

Contact Helsinki IT and request these items:

- [ ] **SSH access** to the server (username and password/key)
- [ ] **Server IP address** or hostname (e.g., `soorena.helsinki.fi`)
- [ ] **SSL certificate file** (`.crt` file)
- [ ] **SSL private key file** (`.key` file)
- [ ] **Domain name** (e.g., `soorena.helsinki.fi`) - or you can use IP temporarily

**Don't start deployment until you have all of these!**

---

## STEP 1: Get the SOORENA Code on Your Computer

**1. Install Git LFS first** (required for large files):

**On Mac:**
```bash
brew install git-lfs
git lfs install
```

**On Linux:**
```bash
sudo apt install git-lfs
git lfs install
```

**On Windows:**
Download from: https://git-lfs.github.com/

**2. Clone the repository:**
```bash
git clone https://github.com/YOUR_ORG/SOORENA_2.git
cd SOORENA_2
```



**3. Pull LFS files:**
```bash
git lfs pull
```

This downloads the large database file needed for the app.

---

## STEP 2: Get the Database File

The application needs a 247 MB database file: `predictions.db`

### Check if you have it:
```bash
ls -lh shiny_app/data/predictions.db
```

**If the file exists (247M):** You're good! Skip to Step 3.

**If the file is missing or tiny (few KB):** You need to get it.

### How to get it:

#### Option A: Download from Git LFS (if it's in the repo)
```bash
cd SOORENA_2
git lfs pull
```

#### Option B: Ask Hala for a download link
If the database isn't in Git LFS, download it via google drive:


https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM?usp=sharing


Download predictions.db and place it here:

```
SOORENA_2/shiny_app/data/predictions.db
```

**Verify you have the database:**
```bash
ls -lh shiny_app/data/predictions.db
# Should show: -rw-r--r-- ... 247M ... predictions.db
```

---

## STEP 3: Deploy to Helsinki Server

Now that you have the code and database, follow these steps:

### Simple 5-Step Process:

```
1. SSH into Helsinki server
   ↓
2. Run server setup script (installs R, Shiny, Nginx - 20-30 min)
   ↓
3. Configure Nginx with SSL certificates (10 min)
   ↓
4. Run deployment script from your computer (uploads app - 5-10 min)
   ↓
5. Test at https://your-domain.helsinki.fi/soorena/
```

### Detailed Instructions:

**Open [DETAILED_GUIDE.md](DETAILED_GUIDE.md) and follow Parts 1-6**

The detailed guide includes:
- Exact commands to copy-paste
- Expected output for each step
- Troubleshooting for common issues
- Testing and verification steps

**Quick links to guide sections:**
- Part 1: Connect to server and verify specs
- Part 2: Install software (or use automated script)
- Part 3: Configure Shiny Server
- Part 4: Configure Nginx with SSL certificates
- Part 5: Deploy application files
- Part 6: Test and verify

---

## Quick Deployment (Experienced Users)

If you're comfortable with Linux servers:

**1. On the Helsinki server:**
```bash
# Copy the setup script to server
scp Jehad/scripts/helsinki_server_setup.sh YOUR_USER@SERVER_IP:/tmp/

# SSH into server
ssh YOUR_USER@SERVER_IP

# Run setup script
bash /tmp/helsinki_server_setup.sh
```

**2. Configure SSL certificates:**
```bash
# Upload certificates from IT
sudo mkdir -p /etc/ssl/helsinki
sudo mv YOUR_CERT.crt /etc/ssl/helsinki/
sudo mv YOUR_KEY.key /etc/ssl/helsinki/
sudo chmod 644 /etc/ssl/helsinki/*.crt
sudo chmod 600 /etc/ssl/helsinki/*.key

# Install Nginx config
sudo cp /path/to/nginx_helsinki.conf /etc/nginx/sites-available/soorena
# Edit to replace YOUR_DOMAIN.helsinki.fi with actual domain
sudo nano /etc/nginx/sites-available/soorena
sudo ln -s /etc/nginx/sites-available/soorena /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Configure firewall
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw --force enable
```

**3. Deploy application (from your computer):**
```bash
cd SOORENA_2/Jehad/scripts
bash helsinki_deploy_app.sh
```

**4. Test:**
```
https://YOUR_DOMAIN.helsinki.fi/soorena/
```

---

## Getting Help

**If you get stuck:**

1. **Check the troubleshooting section** in [DETAILED_GUIDE.md](DETAILED_GUIDE.md) (Part 7)
   - Common errors and solutions
   - How to read logs
   - Step-by-step debugging

2. **Check service logs:**
   ```bash
   sudo tail -50 /var/log/shiny-server.log
   sudo tail -50 /var/log/nginx/soorena_error.log
   ```

3. **Contact Hala:**
   - Describe what step you're on
   - Copy-paste any error messages
   - Share relevant log output

---

## Success Checklist

Deployment is successful when all of these work:

- [ ] Can access `https://YOUR_DOMAIN.helsinki.fi/soorena/` in browser
- [ ] No SSL warnings (green padlock in browser)
- [ ] Dashboard loads with SOORENA header and logos
- [ ] All tabs work (Dashboard, Data Explorer, Statistics, About, Ontology)
- [ ] Can filter data and see results update
- [ ] Can search for proteins
- [ ] Can export data to CSV
- [ ] Images and logos display correctly

---

## File Reference

### Scripts You'll Use:

**`scripts/helsinki_server_setup.sh`**
- **What it does:** Installs R, Shiny Server, Nginx, and all dependencies
- **Where to run:** On the Helsinki server (via SSH)
- **How long:** 20-30 minutes
- **When to use:** First time setting up the server

**`scripts/helsinki_deploy_app.sh`**
- **What it does:** Uploads app files and database to server
- **Where to run:** On your local computer
- **How long:** 5-10 minutes
- **When to use:** Initial deployment and updates

### Configuration Files:

**`configs/nginx_helsinki.conf`**
- Nginx reverse proxy configuration
- Handles HTTPS/SSL
- You'll need to update domain name in this file

**`configs/shiny-server_helsinki.conf`**
- Shiny Server configuration
- Optimized for 247 MB database
- Ready to use as-is

---

## Updating the Application Later

When Hala sends updates to the application:

**For code changes only (app.R):**
```bash
# Get latest code
cd SOORENA_2
git pull

# Deploy
cd Jehad/scripts
bash helsinki_deploy_app.sh
```

**For database updates:**
```bash
# Get latest database (from Hala or regenerate)
cd SOORENA_2
git lfs pull  # if in LFS

# Deploy
cd Jehad/scripts
bash helsinki_deploy_app.sh
```

The deployment script handles everything automatically.

---

## Understanding the Architecture

**Simple explanation of how it works:**

```
User's Browser
    ↓
    ↓ (HTTPS - port 443)
    ↓
Nginx (web server)
    - Handles SSL certificates
    - Adds security
    ↓
    ↓ (HTTP - port 3838, localhost only)
    ↓
Shiny Server
    - Runs R application
    ↓
    ↓
SOORENA Application
    - app.R (main code)
    - predictions.db (database)
    - www/ (images, logos)
```

**Why this setup?**
- Shiny Server can't do HTTPS directly
- Nginx acts as a secure gateway
- This is standard for institutional deployments

---

## Additional Resources

**Official Documentation:**
- R: https://www.r-project.org/
- Shiny Server: https://docs.posit.co/shiny-server/
- Nginx: https://nginx.org/en/docs/

**In the detailed guide:**
- Complete configuration examples
- Security best practices
- Monitoring and maintenance
- Backup strategies

---

## Acknowledgments

Thank you for deploying SOORENA to the Helsinki server. This makes the application accessible to researchers and helps with the manuscript submission.

If you have any questions or run into issues, don't hesitate to reach out to Hala.


---

**Quick Start Reminder:**
1. Get IT credentials and SSL certificates
2. Clone repo and get database file
3. Open [DETAILED_GUIDE.md](DETAILED_GUIDE.md) and follow Parts 1-6
4. Test at `https://your-domain.helsinki.fi/soorena/`
