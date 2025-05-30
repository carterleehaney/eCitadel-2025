#!/bin/bash
# TTU CCDC | Behnjamin Barlow

# Prompt the user for MySQL credentials
read -p "Enter MySQL username: " USER
read -sp "Enter MySQL password: " PASS
echo ""

# Prompt the user for the MySQL host and database (optional)
read -p "Enter MySQL host (default: localhost): " HOST
HOST=${HOST:-localhost}

# Temporary file to store the dump output
OUTPUT_FILE="mysql_dump_output.txt"

# Clear the output file if it already exists
> $OUTPUT_FILE

# Add header to the output file
echo "==========================================" >> $OUTPUT_FILE
echo "          MySQL Dump - Grants, Users, and Tables" >> $OUTPUT_FILE
echo "==========================================" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Dump the user privileges (GRANTS)
echo "[*] Dumping MySQL user grants..." >> $OUTPUT_FILE
echo "------------------------------------------" >> $OUTPUT_FILE
GRANTS=$(mysql -u "$USER" -p"$PASS" -h "$HOST" -e "SHOW GRANTS FOR '$USER'@'$HOST';")
echo "$GRANTS" | sed 's/GRANT/  GRANT/' >> $OUTPUT_FILE # Adds some indentation for readability
echo "" >> $OUTPUT_FILE

# Dump all users in the system with proper table formatting
echo "[*] Dumping MySQL users..." >> $OUTPUT_FILE
echo "----------------------------------------" >> $OUTPUT_FILE
mysql -u "$USER" -p"$PASS" -h "$HOST" -e "SELECT user, host FROM mysql.user;" | \
    awk 'BEGIN { print "+-----------------------+-------------------+"; print "| User                  | Host              |"; print "+-----------------------+-------------------+" } \
    { printf "| %-21s | %-17s |\n", $1, $2 } END { print "+-----------------------+-------------------+" }' >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Dump the list of tables in all databases with improved formatting
echo "[*] Dumping list of tables in all databases..." >> $OUTPUT_FILE
echo "--------------------------------------------------" >> $OUTPUT_FILE
databases=$(mysql -u "$USER" -p"$PASS" -h "$HOST" -e "SHOW DATABASES;" | grep -vE "Database|information_schema|performance_schema|sys|mysql")

for db in $databases; do
    echo "[*] Dumping tables in database: $db" >> $OUTPUT_FILE
    echo "-------------------------------------------" >> $OUTPUT_FILE
    tables=$(mysql -u "$USER" -p"$PASS" -h "$HOST" -e "SHOW TABLES IN $db;")
    echo "$tables" | awk 'BEGIN { print "+------------------+"; print "| Tables_in_db     |"; print "+------------------+" } \
    { printf "| %-16s |\n", $1 } END { print "+------------------+" }' >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
done

# Add a footer to indicate completion
echo "==========================================" >> $OUTPUT_FILE
echo "         MySQL Dump Completed Successfully" >> $OUTPUT_FILE
echo "==========================================" >> $OUTPUT_FILE

# Notify the user that the dump is complete
echo "[*] MySQL dump completed. Output saved to $OUTPUT_FILE"
