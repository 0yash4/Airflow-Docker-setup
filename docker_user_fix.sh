#!/bin/bash

# Quick script to fix Docker user permissions
# Since Docker is already installed, this just adds the user to the docker group

set -e

# Get current user (when run with sudo, get the actual user, not root)
if [ "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER=$(whoami)
fi

echo "Adding user '$CURRENT_USER' to the docker group..."
usermod -aG docker "$CURRENT_USER"

# Also add to ubuntu group if it exists
if getent group ubuntu >/dev/null 2>&1; then
    echo "Adding user '$CURRENT_USER' to the ubuntu group..."
    usermod -aG ubuntu "$CURRENT_USER"
    echo "User added to ubuntu group."
fi

# Ensure Docker service is running
echo "Ensuring Docker service is running..."
systemctl enable docker
systemctl start docker

echo "SUCCESS: User '$CURRENT_USER' has been added to the docker group."
echo "Please log out and log back in (or run 'newgrp docker') for changes to take effect."
echo "After that, you should be able to run: docker run hello-world"

# Show current groups
echo "Current groups for user '$CURRENT_USER':"
groups "$CURRENT_USER"