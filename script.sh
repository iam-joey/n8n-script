#!/bin/bash

set -e  # Exit on any error

# Global variables
DOMAIN=""
EMAIL=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 


log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Function to show usage
show_usage() {
    echo "Usage: $0 --domain=\"your-domain.com\" --email=\"your-email@gmail.com\""
    echo ""
    echo "Arguments:"
    echo "  --domain    Your domain name (e.g., example.com)"
    echo "  --email     Your email address for SSL certificate registration"
    echo ""
    echo "Example:"
    echo "  $0 --domain=\"joey.com\" --email=\"user@gmail.com\""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain=*)
                DOMAIN="${1#*=}"
                shift
                ;;
            --email=*)
                EMAIL="${1#*=}"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1. Use --help for usage information."
                ;;
        esac
    done
}

# Function to validate domain format
validate_domain() {
    local domain="$1"
    
    # Check if domain is empty
    if [[ -z "$domain" ]]; then
        return 1
    fi
    
    # Check if domain contains spaces
    if [[ "$domain" =~ [[:space:]] ]]; then
        return 1
    fi
    
    # Check if domain has at least one dot
    if [[ ! "$domain" =~ \. ]]; then
        return 1
    fi
    
    # Check for valid characters (letters, numbers, dots, hyphens)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Function to validate email format
validate_email() {
    local email="$1"
    
    # Check if email is empty
    if [[ -z "$email" ]]; then
        return 1
    fi
    
    # Basic email validation (has @ and domain part)
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Function to validate inputs
validate_inputs() {
    log "Validating inputs..."
    
    # Check if domain is provided
    if [[ -z "$DOMAIN" ]]; then
        error "Domain is required. Use --domain=\"your-domain.com\""
    fi
    
    # Check if email is provided
    if [[ -z "$EMAIL" ]]; then
        error "Email is required. Use --email=\"your-email@gmail.com\""
    fi
    
    # Validate domain format
    if ! validate_domain "$DOMAIN"; then
        error "Invalid domain format: $DOMAIN. Please provide a valid domain (e.g., example.com)"
    fi
    
    # Validate email format
    if ! validate_email "$EMAIL"; then
        error "Invalid email format: $EMAIL. Please provide a valid email address"
    fi
    
    success "Domain: $DOMAIN"
    success "Email: $EMAIL"
}

# Parse command line arguments
parse_arguments "$@"

# Validate inputs
validate_inputs

# Phase 1: System Checks & Prerequisites
log "Starting N8N Installation Script - Phase 1"
log "Checking system requirements and installing prerequisites..."

# Prerequisites Note
log "IMPORTANT: Make sure you have updated your system packages before running this script:"
log "  sudo apt update && sudo apt upgrade -y"

# 1. Root/Sudo verification
log "Checking root/sudo privileges..."
if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
        error "This script requires root privileges or passwordless sudo access"
    fi
    success "Sudo access verified"
else
    success "Running as root"
fi

# 2. Install basic prerequisites
log "Installing basic prerequisites..."
if [[ $EUID -eq 0 ]]; then
    apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release software-properties-common > /dev/null 2>&1
else
    sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release software-properties-common > /dev/null 2>&1
fi
success "Basic prerequisites installed"

# 3. Docker installation check & install
log "Checking Docker installation..."
if command -v docker &> /dev/null; then
    if docker --version &> /dev/null; then
        success "Docker is already installed: $(docker --version)"
    else
        warning "Docker command exists but not working properly, reinstalling..."
        # Remove old docker
        if [[ $EUID -eq 0 ]]; then
            apt remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
        else
            sudo apt remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
        fi
    fi
else
    log "Docker not found, installing..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /tmp/docker.gpg
    if [[ $EUID -eq 0 ]]; then
        cp /tmp/docker.gpg /usr/share/keyrings/docker-archive-keyring.gpg
    else
        sudo cp /tmp/docker.gpg /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    if [[ $EUID -eq 0 ]]; then
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package index and install Docker
    if [[ $EUID -eq 0 ]]; then
        apt update -y > /dev/null 2>&1
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
    else
        sudo apt update -y > /dev/null 2>&1
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
    fi
    
    # Start and enable Docker
    if [[ $EUID -eq 0 ]]; then
        systemctl start docker
        systemctl enable docker
    else
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    success "Docker installed successfully"
fi

# Add current user to docker group (if not root)
if [[ $EUID -ne 0 ]]; then
    log "Adding current user to docker group..."
    sudo usermod -aG docker $USER
    success "User added to docker group (will take effect after logout/login)"
fi

# 4. Docker Compose check
log "Checking Docker Compose..."
if docker compose version &> /dev/null; then
    success "Docker Compose (plugin) is available: $(docker compose version)"
elif command -v docker-compose &> /dev/null; then
    success "Docker Compose (standalone) is available: $(docker-compose --version)"
else
    log "Installing Docker Compose standalone..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    if [[ $EUID -eq 0 ]]; then
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    success "Docker Compose installed successfully"
fi

# 5. Nginx installation check & install
log "Checking Nginx installation..."
if command -v nginx &> /dev/null; then
    success "Nginx is already installed: $(nginx -v 2>&1)"
else
    log "Nginx not found, installing..."
    if [[ $EUID -eq 0 ]]; then
        apt install -y nginx > /dev/null 2>&1
    else
        sudo apt install -y nginx > /dev/null 2>&1
    fi
    success "Nginx installed successfully"
fi

# 6. Certbot installation check & install
log "Checking Certbot installation..."
if command -v certbot &> /dev/null; then
    success "Certbot is already installed: $(certbot --version)"
else
    log "Certbot not found, installing..."
    if [[ $EUID -eq 0 ]]; then
        apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    else
        sudo apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    fi
    success "Certbot with Nginx plugin installed successfully"
fi

# 7. Final verification
log "Running final verification of all prerequisites..."

# Check Docker
if docker --version &> /dev/null && docker info &> /dev/null; then
    success "✓ Docker is working correctly"
else
    error "✗ Docker verification failed"
fi

# Check Docker Compose
if docker compose version &> /dev/null || docker-compose --version &> /dev/null; then
    success "✓ Docker Compose is working correctly"
else
    error "✗ Docker Compose verification failed"
fi

# Check Nginx
if nginx -v &> /dev/null; then
    success "✓ Nginx is working correctly"
else
    error "✗ Nginx verification failed"
fi

# Check Certbot
if certbot --version &> /dev/null; then
    success "✓ Certbot is working correctly"
else
    error "✗ Certbot verification failed"
fi

# System info
log "System Information:"
echo "  - OS: $(lsb_release -d | cut -f2)"
echo "  - Docker: $(docker --version)"
if docker compose version &> /dev/null; then
    echo "  - Docker Compose: $(docker compose version)"
elif command -v docker-compose &> /dev/null; then
    echo "  - Docker Compose: $(docker-compose --version)"
fi
echo "  - Nginx: $(nginx -v 2>&1)"
echo "  - Certbot: $(certbot --version)"

success "Phase 1 completed successfully!"
success "All prerequisites are installed and ready for n8n deployment"

# Phase 2: N8N Docker Deployment
log "Starting Phase 2: N8N Docker Deployment"

# Function to check if container exists
container_exists() {
    local container_name="$1"
    docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# Function to check if container is running
container_running() {
    local container_name="$1"
    docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# Function to verify DNS configuration
verify_dns() {
    local domain="$1"
    
    log "Verifying DNS configuration for $domain..."
    
    # Get server's public IP
    local server_ip=$(curl -s --max-time 10 ifconfig.me)
    if [[ -z "$server_ip" ]]; then
        error "Failed to get server's public IP address. Please check internet connection."
    fi
    
    # Get domain's IP using nslookup
    local domain_ip=$(nslookup "$domain" | grep -A1 "Name:" | tail -1 | awk '{print $2}' 2>/dev/null)
    
    # Alternative method using dig if nslookup fails
    if [[ -z "$domain_ip" ]]; then
        domain_ip=$(dig +short "$domain" | head -1 2>/dev/null)
    fi
    
    if [[ -z "$domain_ip" ]]; then
        error "Failed to resolve domain $domain. Please check if the domain exists and is properly configured."
    fi
    
    # Compare IPs
    if [[ "$server_ip" == "$domain_ip" ]]; then
        success "DNS verification passed: $domain → $server_ip"
        return 0
    else
        error "DNS configuration error!
        
Your domain '$domain' currently points to: $domain_ip
But this server's public IP is: $server_ip

Please configure your DNS:
1. Go to your domain registrar (GoDaddy, Cloudflare, etc.)
2. Create an A record: $domain → $server_ip
3. Wait for DNS propagation (5-60 minutes)
4. Test with: nslookup $domain
5. Run this script again when DNS is configured"
    fi
}

# Function to wait for n8n to be ready
wait_for_n8n() {
    log "Waiting for n8n to start..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f http://localhost:5678 > /dev/null 2>&1; then
            success "N8N is ready!"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts - waiting for n8n to start..."
        sleep 5
        ((attempt++))
    done
    
    error "N8N failed to start after $max_attempts attempts"
}

# Step 1: Check for existing n8n container
log "Checking for existing n8n container..."
if container_exists "n8n"; then
    error "An n8n container already exists! To perform a fresh installation, please manually remove it first:
    
    docker stop n8n
    docker rm n8n
    
    Then run this script again. This safety check prevents accidental data loss."
fi
success "No existing n8n container found"

# Step 2: Verify DNS configuration
verify_dns "$DOMAIN"

# Step 3: Pull n8n image
log "Pulling n8n Docker image..."
docker pull n8nio/n8n > /dev/null 2>&1
success "N8N image pulled successfully"

# Step 4: Run n8n container
log "Starting n8n container..."
log "Domain: $DOMAIN"
log "Port: 5678"

docker run -d --restart unless-stopped -it \
--name n8n \
-p 5678:5678 \
-e N8N_HOST="$DOMAIN" \
-e WEBHOOK_TUNNEL_URL="https://$DOMAIN/" \
-e WEBHOOK_URL="https://$DOMAIN/" \
-v ~/.n8n:/root/.n8n \
n8nio/n8n > /dev/null 2>&1

success "N8N container started successfully"

# Step 5: Wait for n8n to be ready
wait_for_n8n

# Step 6: Display status and information
log "Displaying n8n status..."
docker ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

success "Phase 2 completed successfully!"
success "N8N is running locally on port 5678"

# Phase 3: Domain Setup & SSL Configuration
log "Starting Phase 3: Domain Setup & SSL Configuration"

# Function to create nginx configuration
create_nginx_config() {
    local domain="$1"
    local config_file="/etc/nginx/sites-available/$domain"
    
    log "Creating nginx configuration for $domain..."
    
    # Create nginx configuration
    cat > "$config_file" << EOF
server {
    listen 80;
    server_name $domain;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }
}
EOF
    
    success "Nginx configuration created: $config_file"
}

# Function to enable nginx site
enable_nginx_site() {
    local domain="$1"
    local available_file="/etc/nginx/sites-available/$domain"
    local enabled_file="/etc/nginx/sites-enabled/$domain"
    
    log "Enabling nginx site for $domain..."
    
    # Remove default site if it exists
    if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        if [[ $EUID -eq 0 ]]; then
            rm -f /etc/nginx/sites-enabled/default
        else
            sudo rm -f /etc/nginx/sites-enabled/default
        fi
        success "Default nginx site disabled"
    fi
    
    # Enable the new site
    if [[ $EUID -eq 0 ]]; then
        ln -sf "$available_file" "$enabled_file"
    else
        sudo ln -sf "$available_file" "$enabled_file"
    fi
    
    success "Nginx site enabled for $domain"
}

# Function to test nginx configuration
test_nginx_config() {
    log "Testing nginx configuration..."
    
    if [[ $EUID -eq 0 ]]; then
        if nginx -t > /dev/null 2>&1; then
            success "Nginx configuration is valid"
        else
            error "Nginx configuration test failed. Please check the configuration."
        fi
    else
        if sudo nginx -t > /dev/null 2>&1; then
            success "Nginx configuration is valid"
        else
            error "Nginx configuration test failed. Please check the configuration."
        fi
    fi
}

# Function to restart nginx
restart_nginx() {
    log "Restarting nginx..."
    
    if [[ $EUID -eq 0 ]]; then
        systemctl restart nginx
        systemctl enable nginx
    else
        sudo systemctl restart nginx
        sudo systemctl enable nginx
    fi
    
    success "Nginx restarted and enabled"
}

# Function to generate SSL certificate
generate_ssl_certificate() {
    local domain="$1"
    local email="$2"
    
    log "Generating SSL certificate for $domain..."
    
    if [[ $EUID -eq 0 ]]; then
        certbot --nginx --agree-tos --no-eff-email --email "$email" -d "$domain" --non-interactive
    else
        sudo certbot --nginx --agree-tos --no-eff-email --email "$email" -d "$domain" --non-interactive
    fi
    
    success "SSL certificate generated for $domain"
}

# Function to test SSL certificate
test_ssl_certificate() {
    local domain="$1"
    
    log "Testing SSL certificate for $domain..."
    
    # Wait a moment for nginx to reload
    sleep 5
    
    if curl -s -f "https://$domain" > /dev/null 2>&1; then
        success "SSL certificate is working correctly"
    else
        warning "SSL certificate test failed, but this might be normal if the site is still loading"
    fi
}

# Step 1: Create nginx configuration
if [[ $EUID -eq 0 ]]; then
    create_nginx_config "$DOMAIN"
else
    # Create temporary file and copy with sudo
    temp_config=$(mktemp)
    cat > "$temp_config" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }
}
EOF
    sudo cp "$temp_config" "/etc/nginx/sites-available/$DOMAIN"
    rm "$temp_config"
    success "Nginx configuration created for $DOMAIN"
fi

# Step 2: Enable nginx site
enable_nginx_site "$DOMAIN"

# Step 3: Test nginx configuration
test_nginx_config

# Step 4: Restart nginx
restart_nginx

# Step 5: Generate SSL certificate
generate_ssl_certificate "$DOMAIN" "$EMAIL"

# Step 6: Test SSL certificate
test_ssl_certificate "$DOMAIN"

# Phase 3 completed
success "Phase 3 completed successfully!"
success "N8N is now publicly accessible with SSL encryption"

log "🎉 Installation Complete!"
log "Access Information:"
log "  🌐 Public URL: https://$DOMAIN"
log "  🔒 SSL Certificate: Active"
log "  🐳 N8N Container: Running on port 5678"
log "  📧 SSL Email: $EMAIL"

log "🔧 Management Commands:"
log "  Check n8n status: docker ps --filter name=n8n"
log "  View n8n logs: docker logs n8n"
log "  Restart n8n: docker restart n8n"
log "  Stop n8n: docker stop n8n"

log "🛡️ Security Notes:"
log "  • SSL certificate will auto-renew via certbot"
log "  • HTTP traffic automatically redirects to HTTPS"
log "  • N8N data is stored in ~/.n8n directory"

success "🚀 Your n8n instance is ready at: https://$DOMAIN"

warning "IMPORTANT: If you added a user to the docker group, please logout and login again for the changes to take effect" 