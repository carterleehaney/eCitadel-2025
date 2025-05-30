#!/bin/bash
# PostgreSQL Dump Script - Dump all databases, users, and grants

# Prompt the user for PostgreSQL username
read -p "Enter PostgreSQL username: " USER

# Prompt the user for PostgreSQL password securely
read -sp "Enter PostgreSQL password: " PASS
echo ""

# Prompt the user for the PostgreSQL host (optional)
read -p "Enter PostgreSQL host (default: localhost): " HOST
HOST=${HOST:-localhost}

# Temporary file to store the dump output
OUTPUT_FILE="postgres_dump_output.txt"

# Clear the output file if it already exists
> $OUTPUT_FILE

# Add header to the output file
echo "==========================================" >> $OUTPUT_FILE
echo "       PostgreSQL Dump - All Databases, Users, and Grants" >> $OUTPUT_FILE
echo "==========================================" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Export the password to use with psql and pg_dump commands
export PGPASSWORD="$PASS"

# Dump the list of all PostgreSQL users and their grants
echo "[*] Dumping PostgreSQL users and their grants..." >> $OUTPUT_FILE
echo "-------------------------------------------------" >> $OUTPUT_FILE
psql -U "$USER" -h "$HOST" -d postgres -c "SELECT usename, grantee, privilege_type FROM information_schema.role_table_grants WHERE grantee NOT IN ('postgres');" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Dump all databases
echo "[*] Dumping list of databases..." >> $OUTPUT_FILE
echo "----------------------------------" >> $OUTPUT_FILE
databases=$(psql -U "$USER" -h "$HOST" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

# Loop through all databases and dump their tables and schemas
for db in $databases; do
    echo "[*] Dumping tables in database: $db..." >> $OUTPUT_FILE
    echo "-------------------------------------------------" >> $OUTPUT_FILE

    # Dump the list of tables for each database
    tables=$(psql -U "$USER" -h "$HOST" -d "$db" -c "\dt" | awk '{if(NR>2) print $3}')

    for table in $tables; do
        echo "[*] Dumping table: $table" >> $OUTPUT_FILE
        echo "---------------------------------" >> $OUTPUT_FILE
        psql -U "$USER" -h "$HOST" -d "$db" -c "\d+ $table" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    done

    # Dump the schema (structure) of the database
    echo "[*] Dumping schema (structure) of database: $db..." >> $OUTPUT_FILE
    echo "----------------------------------------------------------" >> $OUTPUT_FILE
    pg_dump -U "$USER" -h "$HOST" -s "$db" >> "$OUTPUT_FILE"
    echo "" >> $OUTPUT_FILE

    # Dump the data of the database
    echo "[*] Dumping data of database: $db..." >> $OUTPUT_FILE
    echo "------------------------------------------" >> $OUTPUT_FILE
    pg_dump -U "$USER" -h "$HOST" -a "$db" >> "$OUTPUT_FILE"
    echo "" >> $OUTPUT_FILE
done

# Add a footer to indicate completion
echo "==========================================" >> $OUTPUT_FILE
echo "         PostgreSQL Dump Completed Successfully" >> $OUTPUT_FILE
echo "==========================================" >> $OUTPUT_FILE

# Notify the user that the dump is complete
echo "[*] PostgreSQL dump completed. Output saved to $OUTPUT_FILE"
