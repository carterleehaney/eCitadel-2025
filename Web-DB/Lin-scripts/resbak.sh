#!/bin/bash

# Check if the correct number of arguments is passed
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <encrypted_file_path> <target_directory> <password>"
    exit 1
fi

# Assign input arguments to variables
encrypted_file="$1"
target_directory="$2"
password="$3"

# Check if the encrypted file exists
if [ ! -f "$encrypted_file" ]; then
    echo "Error: Encrypted file '$encrypted_file' does not exist."
    exit 1
fi

# Check if the target directory exists
if [ ! -d "$target_directory" ]; then
    echo "Error: Target directory '$target_directory' does not exist."
    exit 1
fi

# Get the name of the target directory to create a temporary working folder
dir_name=$(basename "$target_directory")

# Generate the output decrypted tar file name
decrypted_file="/tmp/$(basename "$encrypted_file" .gpg).tar"

# Decrypt the file
echo "Decrypting file '$encrypted_file'..."
gpg --batch --yes --passphrase "$password" -o "$decrypted_file" -d "$encrypted_file"

# Check if the decryption was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to decrypt the file."
    exit 1
fi

# Create a temporary directory to extract the contents before replacing the target directory
temp_dir="/tmp/$dir_name"
mkdir -p "$temp_dir"

# Extract the decrypted tar file to the temporary directory
echo "Extracting '$decrypted_file' to '$temp_dir'..."
tar -xf "$decrypted_file" -C "$temp_dir"

# Check if extraction was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract the tar file."
    exit 1
fi

# Remove the original target directory and replace it with the extracted content
echo "Replacing '$target_directory' with the extracted contents..."
rm -rf "$target_directory" && mv "$temp_dir" "$target_directory"

# Clean up the decrypted tar file and temporary directory
rm "$decrypted_file"
rm -rf "$temp_dir"

echo "Decryption, extraction, and replacement completed successfully. The '$target_directory' has been replaced."
