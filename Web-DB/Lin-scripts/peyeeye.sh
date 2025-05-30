#!/bin/bash
# KaliPatriot | TTU CCDC | Landon Byrge | Behnjamin Barlow

# Function to prompt for MySQL credentials if -db argument is passed
prompt_for_mysql_credentials() {
    echo -n "Enter MySQL Username: "
    read USER
    echo -n "Enter MySQL Password: "
    read -s PASS
    echo
}

# Function to search for PII in the database results
search_pii_in_string() {
    local string="$1"

    # Regex patterns for PII
    phone_number_regex='(\([0-9]{3}\) |[0-9]{3}-)[0-9]{3}-[0-9]{4}'
    email_regex='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}'
    ssn_regex='[0-9]{3}-[0-9]{2}-[0-9]{4}'
    credit_card_regex='(?:\d{4}-?){3}\d{4}|(?:\d{4}\s?){3}\d{4}|(?:\d{4}){4}'

    # Check for matches for the regex patterns
    if [[ "$string" =~ $phone_number_regex ]] || [[ "$string" =~ $email_regex ]] || [[ "$string" =~ $ssn_regex ]] || [[ "$string" =~ $credit_card_regex ]]; then
        echo "Potential PII found: $string----------------------------------------"  # Separator for clarity
    fi
}


# Function to search MySQL databases for PII
search_mysql_db() {
    databases=$(mysql -u $USER -p$PASS -e "SHOW DATABASES;" 2>/dev/null | grep -v Database)
    for db in $databases; do
        if [ "$db" != "information_schema" ] && [ "$db" != "performance_schema" ] && [ "$db" != "sys" ] && [ "$db" != "mysql" ]; then
            echo "[+] Checking database: $db for PII."

            # Check tables in the database
            tables=$(mysql -u $USER -p$PASS -e "SHOW TABLES FROM $db;" 2>/dev/null | grep -v Tables)
            for table in $tables; do
                echo "[+] Checking table: $table in database $db"

                # Query the table and check the rows for PII
                rows=$(mysql -u $USER -p$PASS -e "SELECT * FROM $db.$table LIMIT 100;" 2>/dev/null)

                # Only check if rows are returned
                if [ -n "$rows" ]; then
                    while read -r row; do
                        # Skip headers or empty rows
                        if [ -n "$row" ]; then
                            search_pii_in_string "$row"
                        fi
                    done <<< "$rows"
                fi
            done
        fi
    done
}

search_pgsql_db() {
    # Prompt for PostgreSQL credentials
    echo -n "Enter PostgreSQL username: "
    read PG_USER
    echo -n "Enter PostgreSQL password: "
    read -s PG_PASSWORD
    echo

    # Define PostgreSQL connection details
    PG_HOST="localhost"
    PG_PORT="5432"
    OUTPUT_DIR="."  # Current directory for dump files

    # Export password for non-interactive use
    export PGPASSWORD=$PG_PASSWORD

    # List all databases
    DATABASES=$(psql -h $PG_HOST -p $PG_PORT -U $PG_USER -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

    # Loop through each database and dump non-default tables
    for DB in $DATABASES; do
        echo "[+] Checking database: $DB"  # Added this line to print the current database

        # Get list of non-default tables (assuming they are in the 'public' schema and not system tables)
        TABLES=$(psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $DB -t -c "
            SELECT tablename
            FROM pg_catalog.pg_tables
            WHERE schemaname = 'public' AND
                  tablename NOT LIKE 'pg_%' AND
                  tablename <> 'sql_%';
        ")

        # Loop over each table and dump it
        for TABLE in $TABLES; do
            echo "[+] Checking table: $TABLE in database $DB"  # Added this line to print the current table

            DUMP_FILE="${OUTPUT_DIR}/${DB}_${TABLE}.sql"
            pg_dump -h $PG_HOST -p $PG_PORT -U $PG_USER -d $DB -t "public.$TABLE" -f "$DUMP_FILE" 2>/dev/null

            # Check for PII in the dumped data
            grep_for_pii_in_dump "$DUMP_FILE"

            # Delete the dump file after checking for PII
            rm -f "$DUMP_FILE"
        done
    done

    # Clean up
    unset PGPASSWORD
}


grep_for_pii_in_dump() {
    # Function to search for PII in PostgreSQL dump files
    local dump_file="$1"
    echo "[+] Searching dump file $dump_file for PII."
    while IFS= read -r line; do
        search_pii_in_string "$line"
    done < "$dump_file"
}

# If -db is passed, prompt for MySQL credentials and search MySQL databases for PII
if [ "$1" == "-mysql" ]; then
    prompt_for_mysql_credentials

    echo "[+] Checking MySQL databases for PII."
    search_mysql_db
    exit 0
fi

# If -pgsql is passed, prompt for PostgreSQL credentials and search PostgreSQL databases for PII
if [ "$1" == "-pgsql" ]; then
    search_pgsql_db
    exit 0
fi

# Default search functionality if no special argument is provided
if ! [ -z "$1" ]; then
    find_path="$PATH"
fi

grep_for_phone_numbers() {
    grep -RPo '(\([0-9]{3}\) |[0-9]{3}-)[0-9]{3}-[0-9]{4}' $1 2>/dev/null
}

grep_for_email_addresses() {
    grep -RPo '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}' $1 2>/dev/null
}

grep_for_social_security_numbers() {
    grep -RPo '[0-9]{3}-[0-9]{2}-[0-9]{4}' $1 2>/dev/null
}

grep_for_credit_card_numbers() {
    grep -RPo '(?:\d{4}-?){3}\d{4}|(?:\d{4}\s?){3}\d{4}|(?:\d{4}){4}' $1 2>/dev/null
}

find_interesting_files_by_extension() {
    find $1 -type f -name '*.doc' -o -name '*.docx' -o -name '*.xls' -o -name '*.xlsx' -o -name '*.pdf' -o -name '*.ppt' -o -name '*.pptx' -o -name '*.txt' -o -name '*.rtf' -o -name '*.csv' -o -name '*.odt' -o -name '*.ods' -o -name '*.odp' -o -name '*.odg' -o -name '*.odf' -o -name '*.odc' -o -name '*.odb' -o -name '*.odm' -o -name '*.docm' -o -name '*.dotx' -o -name '*.dotm' -o -name '*.dot' -o -name '*.wbk' -o -name '*.xltx' -o -name '*.xltm' -o -name '*.xlt' -o -name '*.xlam' -o -name '*.xlsb' -o -name '*.xla' -o -name '*.xll' -o -name '*.pptm' -o -name '*.potx' -o -name '*.potm' -o -name '*.pot' -o -name '*.ppsx' -o -name '*.ppsm' -o -name '*.pps' -o -name '*.ppam' -o -name '*.pptx' 2>/dev/null
}

search() {
    grep_for_phone_numbers $1
    grep_for_email_addresses $1
    grep_for_social_security_numbers $1
    find_interesting_files_by_extension $1
    grep_for_credit_card_numbers $1
}

# Default functionality (search directories or paths)
if [ "$1" == "-dir" ]; then
    if [ -z "$2" ]; then
        echo "[-] No directory provided. Please specify an absolute directory path."
        exit 1
    fi
    find_path="$2"
    echo "[+] Searching $find_path for PII."

    search $find_path
    exit 0
fi

if ! [ -z "$find_path" ]; then
    echo "[+] Searching $find_path for PII."
    search $find_path
fi

# look in /home
echo "[+] Searching /home for PII."
search /home

# look in /var/www
echo "[+] Searching /var/www for PII."
search /var/www

# if there is vsftpd installed, look in the anon_root and local_root directories
check_vsftpd_config() {
    if [ -f $1 ] ; then
        echo "[+] VSFTPD config file found at $1. Checking for anon_root and local_root directories."
        if [ -n "$(grep -E '^\s*anon_root' $1)" ]; then
            echo -e "[+] anon_root found. Checking for PII."
            anon_root=$(grep -E '^\s*anon_root' $1 | awk '{print $2}')
            search $anon_root
        fi

        if [ -n "$(grep -E '^\s*local_root' $1)" ]; then
            echo -e "[+] local_root found. Checking for PII."
            local_root=$(grep -E '^\s*local_root' $1 | awk '{print $2}')
            search $local_root
        fi
    fi
}

# Check for vsftpd.conf in common locations
check_vsftpd_config /etc/vsftpd.conf
check_vsftpd_config /etc/vsftpd/vsftpd.conf
check_vsftpd_config /usr/local/etc/vsftpd.conf
check_vsftpd_config /usr/local/vsftpd/vsftpd.conf

#proftpd
if [ -f /etc/proftpd/proftpd.conf ]; then
    echo "[+] ProFTPD config file found. Checking for anon_root and local_root directories."
    if [ -n "$(grep -E '^\s*DefaultRoot' /etc/proftpd/proftpd.conf)" ]; then
        echo -e "[+] DefaultRoot found. Checking for PII."
        default_root=$(grep -E '^\s*DefaultRoot' /etc/proftpd/proftpd.conf | awk '{print $2}')
        search $default_root
    fi
fi

# samba
if [ -f /etc/samba/smb.conf ]; then
    echo "[+] Samba config file found. Checking for shares."
    shares=$(grep -E '^\s*path' /etc/samba/smb.conf | awk '{print $3}' | sed 's/"//g')
    for share in $shares; do
        echo -e "[+] Checking $share for PII."
        search $share
    done
fi
