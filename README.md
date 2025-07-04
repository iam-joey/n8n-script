# N8N Installation Script for Ubuntu

🚀 **One-command installation script** for n8n with Docker, Nginx, and SSL certificates.

## 📋 Table of Contents

- [Overview](#overview)
- [Supported Operating Systems](#supported-operating-systems)
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
- [Usage](#usage)
- [What This Script Does](#what-this-script-does)
- [Firewall Configuration](#firewall-configuration)
- [DNS Configuration](#dns-configuration)
- [Troubleshooting](#troubleshooting)
- [Management Commands](#management-commands)
- [Security Notes](#security-notes)

## 🔍 Overview

This script provides a **complete automated installation** of n8n (workflow automation tool) with:

- ✅ Docker containerization
- ✅ Nginx reverse proxy
- ✅ SSL certificate (Let's Encrypt)
- ✅ Automatic HTTPS redirect
- ✅ Production-ready configuration

## 💻 Supported Operating Systems

- **Ubuntu 24.04 LTS** (Recommended)
- **Ubuntu 22.04 LTS**
- **Ubuntu 20.04 LTS**

> **Note:** This script is specifically designed for **Ubuntu** and has been tested on fresh Ubuntu instances.

## 🛠️ Prerequisites

### 1. **Fresh Ubuntu Instance**

- Use a **new, clean Ubuntu server** for best results
- Minimum 1GB RAM, 1 CPU core
- At least 10GB storage space

### 2. **Domain Name**

- You must own a domain name (e.g., `yourdomain.com`)
- Can be a root domain (`joey.com`) or subdomain (`hello.joey.com`)
- Domain must be pointed to your server's IP address

### 3. **Server Requirements**

- **Root access** or user with sudo privileges
- **Internet connection** for downloading packages
- **Ports 80 and 443** must be accessible from the internet

### 4. **Email Address**

- Valid email address for SSL certificate registration

## 🚀 Installation Steps

### Step 1: Switch to Root User

**⚠️ IMPORTANT:** Switch to root user before proceeding:

```bash
sudo su
```

### Step 2: Update Your System

**⚠️ IMPORTANT:** Always update your system before running the script:

```bash
apt update && apt upgrade -y
```

### Step 3: Configure DNS

Before running the script, ensure your domain points to your server:

**For Root Domain (e.g., `joey.com`):**

1. Go to your domain registrar (GoDaddy, Cloudflare, etc.)
2. Create an **A record**: `@` → `your-server-ip`
3. Wait for DNS propagation (5-60 minutes)
4. Test DNS: `nslookup joey.com`

**For Subdomain (e.g., `hello.joey.com`):**

1. Go to your domain registrar (GoDaddy, Cloudflare, etc.)
2. Create an **A record**: `hello` → `your-server-ip`
3. Wait for DNS propagation (5-60 minutes)
4. Test DNS: `nslookup hello.joey.com`

### Step 4: Configure Firewall

Ensure ports 80 and 443 are open:

```bash
# Enable firewall
ufw enable

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp

# Check status
ufw status
```

### Step 5: Download and Run the Script

```bash
# Download the script
wget https://raw.githubusercontent.com/iam-joey/n8n-script/main/script.sh

# Make it executable
chmod +x script.sh

# Run the installation
./script.sh --domain="yourdomain.com" --email="your-email@gmail.com"
```

## 📖 Usage

### Basic Usage

```bash
./script.sh --domain="yourdomain.com" --email="your-email@gmail.com"
```

### Help

```bash
./script.sh --help
```

### Examples

**Root Domain:**

```bash
./script.sh --domain="joey.com" --email="admin@joey.com"
```

**Subdomain:**

```bash
./script.sh --domain="n8n.joey.com" --email="admin@joey.com"
./script.sh --domain="hello.joey.com" --email="admin@joey.com"
./script.sh --domain="automation.joey.com" --email="admin@joey.com"
```

## 🔄 What This Script Does

### Phase 1: System Prerequisites

- ✅ Checks root/sudo privileges
- ✅ Installs Docker and Docker Compose
- ✅ Installs Nginx web server
- ✅ Installs Certbot for SSL certificates
- ✅ Configures all services

### Phase 2: N8N Docker Deployment

- ✅ Validates domain and email format
- ✅ Checks for existing n8n containers
- ✅ Verifies DNS configuration
- ✅ Pulls and deploys n8n container
- ✅ Configures n8n with your domain
- ✅ Tests local accessibility

### Phase 3: SSL & Public Access

- ✅ Configures Nginx reverse proxy
- ✅ Generates SSL certificate
- ✅ Enables HTTPS with auto-redirect
- ✅ Tests public accessibility
- ✅ Sets up automatic SSL renewal

## 🛡️ Firewall Configuration

### Ubuntu UFW (Uncomplicated Firewall)

```bash
ufw enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
```

### AWS Security Groups

If using AWS EC2, configure Security Groups:

- **HTTP (80)**: Source `0.0.0.0/0`
- **HTTPS (443)**: Source `0.0.0.0/0`
- **SSH (22)**: Source `your-ip/32`

### Google Cloud Firewall

```bash
# Allow HTTP traffic
gcloud compute firewall-rules create allow-http --allow tcp:80 --source-ranges 0.0.0.0/0

# Allow HTTPS traffic
gcloud compute firewall-rules create allow-https --allow tcp:443 --source-ranges 0.0.0.0/0
```

## 🌐 DNS Configuration

### For Root Domain (e.g., `joey.com`)

Create an **A record** in your domain's DNS settings:

| Type | Name | Value          | TTL |
| ---- | ---- | -------------- | --- |
| A    | @    | your-server-ip | 300 |
| A    | www  | your-server-ip | 300 |

### For Subdomain (e.g., `hello.joey.com`)

Create an **A record** for the subdomain:

| Type | Name  | Value          | TTL |
| ---- | ----- | -------------- | --- |
| A    | hello | your-server-ip | 300 |

**Alternative: CNAME Record for Subdomain**

| Type  | Name  | Value    | TTL |
| ----- | ----- | -------- | --- |
| CNAME | hello | joey.com | 300 |

### DNS Record Comparison

| Method           | Pros                                      | Cons                         | Best For                        |
| ---------------- | ----------------------------------------- | ---------------------------- | ------------------------------- |
| **A Record**     | Direct IP pointing, faster resolution     | Need to update if IP changes | Most common, reliable           |
| **CNAME Record** | Follows main domain changes automatically | Extra DNS lookup step        | When IP might change frequently |

### Common Subdomain Examples

- `n8n.yourdomain.com` - Clear purpose identification
- `automation.yourdomain.com` - Descriptive naming
- `workflows.yourdomain.com` - Business-focused naming
- `app.yourdomain.com` - Generic application naming

### Verify DNS

**For Root Domain:**

```bash
# Check if domain resolves to your server
nslookup joey.com
dig joey.com

# Should return your server's IP address
```

**For Subdomain:**

```bash
# Check if subdomain resolves to your server
nslookup hello.joey.com
dig hello.joey.com

# Should return your server's IP address (A record) or main domain (CNAME)
```

## 🔧 Troubleshooting

### Common Issues

#### 1. **SSL Certificate Generation Fails**

**Error:** `Timeout during connect (likely firewall problem)`

**Solution:**

- Ensure ports 80/443 are open in firewall
- Check cloud provider security groups
- Verify DNS is properly configured

#### 2. **Docker Permission Denied**

**Error:** `permission denied while trying to connect to the Docker daemon`

**Solution:**

```bash
# Add user to docker group
usermod -aG docker $USER

# Logout and login again, or run:
newgrp docker
```

#### 3. **Domain Not Resolving**

**Error:** `Failed to resolve domain`

**Solution:**

- Wait for DNS propagation (up to 60 minutes)
- Check DNS configuration at your registrar
- Use `nslookup` to verify DNS resolution

#### 4. **Existing N8N Container**

**Error:** `An n8n container already exists`

**Solution:**

```bash
# Stop and remove existing container
docker stop n8n
docker rm n8n

# Run script again
./script.sh --domain="yourdomain.com" --email="your-email@gmail.com"
```

## 🛠️ Management Commands

### N8N Container Management

```bash
# Check n8n status
docker ps --filter name=n8n

# View n8n logs
docker logs n8n

# Restart n8n
docker restart n8n

# Stop n8n
docker stop n8n

# Start n8n
docker start n8n
```

### SSL Certificate Management

```bash
# Check SSL certificate status
certbot certificates

# Renew SSL certificate manually
certbot renew

# Test SSL renewal
certbot renew --dry-run
```

### Nginx Management

```bash
# Check nginx status
systemctl status nginx

# Restart nginx
systemctl restart nginx

# Test nginx configuration
nginx -t

# View nginx error logs
tail -f /var/log/nginx/error.log
```

## 🔒 Security Notes

### SSL Certificate

- ✅ SSL certificates **auto-renew** every 90 days
- ✅ HTTP traffic **automatically redirects** to HTTPS
- ✅ Strong SSL configuration with modern ciphers

### Data Security

- ✅ N8N data stored in `~/.n8n` directory
- ✅ Automatic backups recommended
- ✅ Regular security updates advised

### Firewall Security

- ✅ Only essential ports (22, 80, 443) should be open
- ✅ SSH access should be restricted to your IP
- ✅ Regular security audits recommended

## 📚 Additional Resources

- [N8N Documentation](https://docs.n8n.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## 🤝 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review the script logs carefully
3. Ensure all prerequisites are met
4. Verify firewall and DNS configuration

## 📄 License

This script is provided as-is for educational and production use. Please review and test in a development environment before production deployment.

---

**🎉 Happy Automating with N8N!**
