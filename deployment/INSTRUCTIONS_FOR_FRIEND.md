# Instructions for Setting Up SOORENA on Your Digital Ocean Account

Hi! Thanks for helping host my research database app. Here's exactly what I need from you.

---

## What You're Helping With

I built a Shiny dashboard called **SOORENA** for analyzing protein research data. It has a 6.1 GB database with 3.37 million records. I need to host it online so my team can access it from anywhere.

---

## Do You Already Have a Droplet?

**If you already have a Digital Ocean droplet running**, we might be able to use it!

Check if it has:
- At least 2 GB RAM (4 GB is better)
- At least 10 GB free disk space
- Ubuntu 20.04, 22.04, or 24.04

If YES → See [USING_EXISTING_DROPLET.md](USING_EXISTING_DROPLET.md) for instructions

If NO or UNSURE → Continue below to create a new one

---

## What I Need From You

### Option A: Give Me Access (Easiest)

1. **Add me as a team member** to your Digital Ocean account:
   - Log into Digital Ocean
   - Go to **Settings** → **Team**
   - Click **Invite Member**
   - Add my email: `_____________` (I'll provide)
   - Give me permission to create/manage droplets
   - I'll create the droplet myself and handle everything

### Option B: Create the Droplet for Me

If you prefer to create it yourself, here's what to do:

---

## Step 1: Create a Droplet

1. Log into [Digital Ocean](https://www.digitalocean.com/)
2. Click the green **Create** button (top right) → **Droplets**

---

## Step 2: Choose These Settings

### Image
- **Choose**: Ubuntu 22.04 or 24.04 (LTS) x64

### Droplet Size
Pick one based on your budget:

**OPTION 1 - Minimum (works but slower):**
- **Type**: Basic
- **CPU**: Regular
- **Size**: 2 GB RAM / 1 vCPU / 50 GB SSD
- **Cost**: $12/month

**OPTION 2 - Recommended (smooth performance):**
- **Type**: Basic
- **CPU**: Regular
- **Size**: 4 GB RAM / 2 vCPUs / 80 GB SSD
- **Cost**: $24/month

**OPTION 3 - Best (optimal performance):**
- **Type**: Basic
- **CPU**: Regular
- **Size**: 8 GB RAM / 4 vCPUs / 160 GB SSD
- **Cost**: $48/month

**My recommendation**: Start with the $24/month option. We can resize later if needed.

### Datacenter Region
- Choose the closest to you (or me)
- Example: **Toronto**, **New York**, or **San Francisco**

### Authentication
Pick ONE:

**OPTION A - SSH Key (Recommended):**
- Click **New SSH Key**
- I'll send you my public SSH key separately
- Paste it in and give it a name like "SOORENA"

**OPTION B - Password (Simpler):**
- Just use password
- Digital Ocean will email you the root password
- Forward that email to me

### Additional Options
- **SKIP** all extras (monitoring, backups, etc.) to save money
- We can add them later if needed

### Hostname
- Name it: `soorena-app`

---

## Step 3: After Creating the Droplet

Once created, I need:

1. **The droplet's public IP address**
   - You'll see it on the droplets page
   - Example: `164.92.XXX.XXX`
   - Send this to me

2. **Access credentials** (depending on what you chose):
   - If SSH key: Nothing else needed!
   - If password: Forward me the email with root password

---

## Step 4: Give Me This Info

Send me a message with:

```
Droplet IP: XXX.XXX.XXX.XXX
Droplet Size: X GB RAM / X vCPUs
Authentication: SSH Key OR Password
[If password: include the password or forward the email]
```

---

## That's It!

Once I have this info, I'll:
1. SSH into the droplet (takes 2 seconds)
2. Run my setup script (takes 15 minutes, automated)
3. Deploy my app (takes 10 minutes, automated)
4. Send you the link to test!

Total time: ~30 minutes of automated installation.

---

## Cost Summary

**Monthly costs:**
- $12/month: Minimum (2 GB RAM) - slower but works
- $24/month: Recommended (4 GB RAM) - smooth performance
- $48/month: Best (8 GB RAM) - optimal experience

**Do you have free credits?**
- New accounts often get $100-200 in free credits
- Students can get additional credits via GitHub Student Pack
- Check your account for any promo credits

**Bandwidth:**
- All plans include 2-4 TB of bandwidth (way more than we need)
- This is a research database, not a high-traffic website

---

## Can I Use It For Free?

**Check your account for credits:**
1. Log into Digital Ocean
2. Go to **Billing** → **Credits**
3. If you see credits, we can run this for FREE for months!

Common credit sources:
- New account bonus ($100-200)
- GitHub Student Pack ($100)
- Promo codes from tech events
- Referral credits

---

## FAQ

**Q: Will this use a lot of resources?**
A: No. It's a research database for my team (5-10 people). Very light usage.

**Q: Can we shut it down when not in use?**
A: Yes! You can power off the droplet and only pay for storage ($1-2/month). I can turn it on/off as needed.

**Q: How long do you need it?**
A: For my research project - probably 6-12 months. We can cancel anytime.

**Q: Can I see what you're deploying?**
A: Absolutely! It's a Shiny dashboard for protein research. Here's the GitHub repo: [link]. You can also test the app once it's live.

**Q: Will you have root access to my account?**
A: No! I only get access to this ONE droplet. I can't see your billing, other droplets, or account settings.

**Q: What if something goes wrong?**
A: You can delete the droplet anytime from your Digital Ocean dashboard. All my data is backed up locally.

---

## Alternative: Just Add Me to Your Team

The absolute easiest option:

1. Go to Digital Ocean → **Settings** → **Team**
2. Click **Invite Member**
3. Enter my email: `_____________`
4. Set permissions: **Can create/manage droplets**
5. I'll handle everything else!

This way you don't have to do anything except click "Invite" 😊

---

## Thank You!

I really appreciate you helping me host this research database. Once it's live, I'll send you the link so you can see what we built!

If you have ANY questions, just ask. I'm here to help!

**- [Your Name]**

---

## Quick Reference: What Size Should I Pick?

| Droplet Size | Cost | Best For | Performance |
|--------------|------|----------|-------------|
| 2 GB RAM | $12/mo | Testing, light use | Slower initial load (30-60 sec) |
| 4 GB RAM | $24/mo | Regular use, small team | Smooth, 10-20 sec load |
| 8 GB RAM | $48/mo | Heavy use, larger team | Fast, instant load |

**My recommendation**: 4 GB RAM ($24/month) - best balance of cost and performance.

---

**Need help?** Text me or call! I can walk you through it in 5 minutes.
