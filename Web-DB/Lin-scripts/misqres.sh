#!/bin/bash

# Function to check and install OpenSSL if missing
install_openssl() {
    echo "Checking for OpenSSL..."
    if ! command -v openssl &>/dev/null; then
        echo "OpenSSL not found. Installing..."

        if [ -f /etc/debian_version ]; then
            # Debian-based (Ubuntu, Debian, etc.)
            sudo apt update && sudo apt install -y openssl

        elif [ -f /etc/redhat-release ]; then
            # RHEL-based (CentOS, Rocky, AlmaLinux, etc.)
            sudo yum install -y openssl

        elif [ -f /etc/fedora-release ]; then
            # Fedora
            sudo dnf install -y openssl

        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            sudo pacman -Sy --noconfirm openssl

        elif [ -f /etc/alpine-release ]; then
            # Alpine Linux
            sudo apk add openssl

        else
            echo "Unsupported Linux distribution. Please install OpenSSL manually."
            exit 1
        fi
    else
        echo "OpenSSL is already installed."
    fi
}

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <DB_USER> <FULL_BACKUP_PATH>"
    exit 1
fi

# Run OpenSSL check and install if needed
install_openssl

# Assign input parameters
DB_USER="$1"
FULL_BACKUP_PATH="$2"

# Check if the backup file exists
if [ ! -f "$FULL_BACKUP_PATH" ]; then
    echo "Backup file not found: $FULL_BACKUP_PATH"
    exit 1
fi

# Temporary decrypted file (remove .enc extension)
DECRYPTED_FILE="${FULL_BACKUP_PATH%.enc}"

# Prompt for encryption password
echo -n "Enter encryption password: "
read -s ENCRYPTION_PASSWORD
echo ""

# Decrypt the backup file
openssl enc -aes-256-cbc -d -salt -pbkdf2 -in "$FULL_BACKUP_PATH" -out "$DECRYPTED_FILE" -pass pass:"$ENCRYPTION_PASSWORD"

# Check if decryption was successful
if [ $? -ne 0 ]; then
    echo "Decryption failed! Wrong password?"
    exit 2
fi

# Prompt for MySQL password (secure input)
echo -n "Enter MySQL password: "
read -s DB_PASSWORD
echo ""

# Restore the backup to MySQL
mysql -u "$DB_USER" --password="$DB_PASSWORD" < "$DECRYPTED_FILE"

# Check if restore was successful
if [ $? -ne 0 ]; then
    echo "Database restore failed!"
    exit 3
fi

# Remove decrypted file for security
rm -f "$DECRYPTED_FILE"

echo "Database restore successful!"
