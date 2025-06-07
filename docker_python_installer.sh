#!/bin/bash

# This script automates the installation of Docker Engine, Docker Compose (plugin),
# and the latest stable Python 3.x version on Ubuntu.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Get the current user's name to add them to the docker group
CURRENT_USER=$(whoami)
# Get the Ubuntu codename dynamically (e.g., focal, jammy, noble)
UBUNTU_CODENAME=$(lsb_release -cs)

# --- Functions for logging and error handling ---
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
    exit 1
}

# --- Pre-installation Checks ---
log_info "Starting installation process..."
log_info "Checking for root privileges..."
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo. Please run: sudo ./install_docker_python.sh"
fi

log_info "Updating system packages..."
# Fix potential apt_pkg issues and disable problematic post-invoke scripts
log_info "Fixing potential apt_pkg module issues..."

# Temporarily disable the problematic command-not-found post-invoke script
CNF_SCRIPT="/etc/apt/apt.conf.d/50command-not-found"
CNF_BACKUP="/etc/apt/apt.conf.d/50command-not-found.backup"

if [ -f "$CNF_SCRIPT" ]; then
    log_info "Temporarily disabling command-not-found apt hook..."
    mv "$CNF_SCRIPT" "$CNF_BACKUP" 2>/dev/null || true
fi

# Try to fix the python3-apt installation
apt install --reinstall -y python3-apt 2>/dev/null || log_warning "Could not reinstall python3-apt."

# Update with the problematic script disabled
if apt update -y; then
    log_success "Apt update successful."
else
    log_warning "Apt update had issues, but continuing..."
fi

# Restore the command-not-found script
if [ -f "$CNF_BACKUP" ]; then
    log_info "Restoring command-not-found apt hook..."
    mv "$CNF_BACKUP" "$CNF_SCRIPT" 2>/dev/null || true
fi

apt upgrade -y || log_warning "Some packages may not have upgraded successfully."
log_success "System packages updated."

# --- Install Docker Engine and Docker Compose Plugin ---
# --- Install Docker Engine and Docker Compose Plugin ---
log_info "Checking if Docker is already installed..."
if command -v docker &> /dev/null; then
    log_info "Docker is already installed. Checking if it's running..."
    if systemctl is-active --quiet docker; then
        log_success "Docker is already installed and running."
        DOCKER_ALREADY_INSTALLED=true
    else
        log_info "Docker is installed but not running. Starting Docker service..."
        systemctl enable docker || log_error "Failed to enable Docker service."
        systemctl start docker || log_error "Failed to start Docker service."
        DOCKER_ALREADY_INSTALLED=true
    fi
else
    DOCKER_ALREADY_INSTALLED=false
    log_info "Installing prerequisites for Docker..."
    apt install -y ca-certificates curl gnupg lsb-release || log_error "Failed to install Docker prerequisites."

    log_info "Adding Docker's official GPG key..."
    install -m 0755 -d /etc/apt/keyrings || log_error "Failed to create /etc/apt/keyrings directory."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || log_error "Failed to download and dearmor Docker GPG key."
    chmod a+r /etc/apt/keyrings/docker.gpg || log_error "Failed to set permissions for Docker GPG key."
    log_success "Docker GPG key added."

    log_info "Adding Docker repository to APT sources..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      ${UBUNTU_CODENAME} stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null || log_error "Failed to add Docker repository."
    log_success "Docker repository added."

    log_info "Updating apt package index with Docker repository..."
    # Temporarily disable command-not-found again for this update
    if [ -f "$CNF_SCRIPT" ]; then
        mv "$CNF_SCRIPT" "$CNF_BACKUP" 2>/dev/null || true
    fi
    
    apt update -y || log_warning "Apt update had issues, but continuing..."
    
    if [ -f "$CNF_BACKUP" ]; then
        mv "$CNF_BACKUP" "$CNF_SCRIPT" 2>/dev/null || true
    fi
    log_success "Apt package index updated."

    log_info "Installing Docker Engine and Docker Compose plugin..."
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || log_error "Failed to install Docker components."
    log_success "Docker Engine and Docker Compose plugin installed."

    log_info "Enabling and starting Docker service..."
    systemctl enable docker || log_error "Failed to enable Docker service."
    systemctl start docker || log_error "Failed to start Docker service."
    log_success "Docker service enabled and started."
fi

log_info "Making Docker service start automatically on boot (default behavior)..."
# Ensure Docker starts automatically - this is usually default but let's be explicit
systemctl daemon-reload || log_warning "Failed to reload systemd daemon."
if systemctl is-enabled docker >/dev/null 2>&1; then
    log_success "Docker service is set to start automatically on boot."
else
    log_warning "Docker service may not start automatically on boot."
fi

log_info "Adding user '$CURRENT_USER' to the 'docker' group..."
usermod -aG docker "$CURRENT_USER" || log_error "Failed to add user to docker group."

# Also add user to ubuntu group if it exists (common on Ubuntu systems)
if getent group ubuntu >/dev/null 2>&1; then
    log_info "Adding user '$CURRENT_USER' to the 'ubuntu' group..."
    usermod -aG ubuntu "$CURRENT_USER" || log_warning "Failed to add user to ubuntu group (this may be normal)."
    log_success "User added to 'ubuntu' group."
else
    log_info "Ubuntu group not found, skipping ubuntu group assignment."
fi

log_warning "You need to log out and log back in (or reboot) for Docker commands to work without 'sudo'."
log_success "User added to 'docker' group."

# --- Install Latest Stable Python 3.x ---
log_info "Installing the 'deadsnakes' PPA for latest Python versions..."

# Fix apt_pkg issues before adding PPA
log_info "Ensuring python3-apt is properly installed..."
apt install --reinstall -y python3-apt 2>/dev/null || log_warning "Could not reinstall python3-apt."

apt update # Update needed before adding PPA, just in case
apt install -y software-properties-common || log_error "Failed to install software-properties-common."

# Add PPA with better error handling
if ! add-apt-repository ppa:deadsnakes/ppa -y; then
    log_warning "Failed to add deadsnakes PPA normally, trying alternative method..."
    # Alternative method using apt-key (for older systems)
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xF23C5A6CF475977595C89F51BA6932366A755776 | apt-key add - 2>/dev/null || true
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/deadsnakes.list
    apt update -y || log_error "Failed to update after adding deadsnakes PPA manually."
fi

log_success "'deadsnakes' PPA added."

log_info "Updating apt package index after adding Python PPA..."
apt update -y || log_error "Failed to update apt packages after adding Python PPA."
log_success "Apt package index updated."

# Find the latest available Python 3.x version from deadsnakes PPA
log_info "Detecting the latest stable Python 3.x version available from deadsnakes PPA..."

# Get available Python versions and find the highest stable version
AVAILABLE_VERSIONS=$(apt-cache search "^python3\.[0-9]+$" | grep -E "python3\.[0-9]+ -" | awk '{print $1}' | sed 's/python//' | sort -V)
LATEST_PYTHON_VERSION=$(echo "$AVAILABLE_VERSIONS" | tail -n 1)

if [ -z "$LATEST_PYTHON_VERSION" ]; then
    log_error "Could not determine the latest stable Python 3.x version from deadsnakes PPA."
else
    log_info "Latest stable Python 3.x detected: python${LATEST_PYTHON_VERSION}"
    log_info "Installing python${LATEST_PYTHON_VERSION} and related packages..."
    
    # Install Python with better error handling for individual packages
    if apt install -y "python${LATEST_PYTHON_VERSION}"; then
        log_success "Python ${LATEST_PYTHON_VERSION} installed."
    else
        log_error "Failed to install python${LATEST_PYTHON_VERSION}."
    fi
    
    # Try to install venv and pip, but don't fail if they're not available
    if apt install -y "python${LATEST_PYTHON_VERSION}-venv" 2>/dev/null; then
        log_success "Python ${LATEST_PYTHON_VERSION} venv installed."
    else
        log_warning "Python ${LATEST_PYTHON_VERSION} venv package not available."
    fi
    
    if apt install -y "python${LATEST_PYTHON_VERSION}-pip" 2>/dev/null; then
        log_success "Python ${LATEST_PYTHON_VERSION} pip installed."
    else
        log_warning "Python ${LATEST_PYTHON_VERSION} pip package not available. Installing pip via get-pip.py..."
        curl -sS https://bootstrap.pypa.io/get-pip.py | "python${LATEST_PYTHON_VERSION}" || log_warning "Failed to install pip via get-pip.py"
    fi

    log_info "Setting Python ${LATEST_PYTHON_VERSION} as the default 'python3' alternative."
    # Remove existing alternatives first to avoid conflicts
    update-alternatives --remove-all python3 2>/dev/null || true
    update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${LATEST_PYTHON_VERSION}" 100 || log_warning "Failed to set default python3 alternative."
    log_success "Attempted to set python3 to version ${LATEST_PYTHON_VERSION}. Verify with 'python3 --version'."

    # Verify pip for the newly installed Python
    if "/usr/bin/python${LATEST_PYTHON_VERSION}" -m pip --version &>/dev/null; then
        PIP_VERSION=$("/usr/bin/python${LATEST_PYTHON_VERSION}" -m pip --version)
        log_success "Pip for Python ${LATEST_PYTHON_VERSION} is installed: ${PIP_VERSION}"
    else
        log_warning "Pip for Python ${LATEST_PYTHON_VERSION} could not be verified."
    fi
fi

# --- Verification ---
log_info "Verifying installations..."

# Docker verification
if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_success "Docker Engine is installed and running (version: ${DOCKER_VERSION})."
else
    log_error "Docker Engine installation failed or is not running."
fi

# Docker Compose verification
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || docker compose version | head -n 1 | awk '{print $NF}' | sed 's/v//')
    log_success "Docker Compose plugin is installed (version: ${COMPOSE_VERSION})."
else
    log_error "Docker Compose plugin installation failed."
fi

# Python verification
if command -v python3 &> /dev/null; then
    INSTALLED_PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    log_success "Python 3 is installed (version: $INSTALLED_PYTHON_VERSION)."
else
    log_error "Python 3 installation failed."
fi

# Final message
log_success "All installations complete. Remember to log out and log back in for Docker sudo-less commands."
log_info "You can verify your Python version by running: python3 --version"
log_info "You can check Docker status with: systemctl status docker"
log_info "You can test Docker with: docker run hello-world"