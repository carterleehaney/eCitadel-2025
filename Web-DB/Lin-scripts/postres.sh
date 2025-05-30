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

# Function to check if PostgreSQL client (`pg_restore`) is installed
check_postgresql_client() {
    if ! command -v pg_restore &>/dev/null; then
        echo "Error: pg_restore not found. Please install PostgreSQL client before running this script."
        exit 1
    fi
}

# Check if correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <DB_USER> <BACKUP_PATH> <BACKUP_FILENAME>"
    exit 1
fi

# Run OpenSSL check and install if needed
install_openssl

# Ensure PostgreSQL client is installed
check_postgresql_client

# Assign input parameters
DB_USER="$1"
BACKUP_PATH="$2"
BACKUP_FILENAME="$3"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# Ensure backup path has a trailing slash
[[ "${BACKUP_PATH: -1}" != "/" ]] && BACKUP_PATH="${BACKUP_PATH}/"

# Define encrypted file path and unencrypted file name

# Define encrypted file path
ENCRYPTED_FILE="${BACKUP_PATH}${BACKUP_FILENAME}"

# Check if the file already has .enc extension to avoid appending it twice
if [[ ! "${ENCRYPTED_FILE}" =~ \.enc$ ]]; then
    ENCRYPTED_FILE="${ENCRYPTED_FILE}.enc"
fi

DECRYPTED_FILE="${BACKUP_PATH}${BACKUP_FILENAME}_${DATE}.sql"

# Prompt for encryption password (secure input)
echo -n "Enter encryption password: "
read -s ENCRYPTION_PASSWORD
echo ""

# Prompt for PostgreSQL password (secure input)
echo -n "Enter PostgreSQL password for user '$DB_USER': "
read -s DB_PASSWORD
echo ""

# Decrypt the backup file
openssl enc -d -aes-256-cbc -pbkdf2 -in "$ENCRYPTED_FILE" -out "$DECRYPTED_FILE" -pass pass:"$ENCRYPTION_PASSWORD"

# Check if decryption was successful
if [ $? -ne 0 ]; then
    echo "Decryption failed!"
    exit 2
fi

# Restore the PostgreSQL database from the decrypted file
PGPASSWORD="$DB_PASSWORD" pg_restore -U "$DB_USER" --no-password --clean --create --format=c --dbname="$DB_USER" "$DECRYPTED_FILE"

# Check if restore was successful
if [ $? -ne 0 ]; then
    echo "Database restore failed!"
    exit 3
fi

# Remove the decrypted backup file after restoring
rm -f "$DECRYPTED_FILE"

echo "Database restore successful!"
