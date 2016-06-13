#!/bin/bash

# This tool can install wordpress, and export or import an entire site and SQL database

# THIS SCRIPT NEED THIS INFO
MYSQL_USER="root"
MYSQL_PASS="PASSWORD"
MYSQL_HOST="localhost"

DATETIME=`date +%Y%m%d%H%M%S`

# Usage message
USAGE_MSG=$'Usage:  ./wputil [install|export|import] (params)\n\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\t*  install  *\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\tUsage: $ ./wputil install -d=/install/dir \'-db=dbname\' \'-u=newuser\' \'-p=pass\'\n'
USAGE_MSG=${USAGE_MSG}$'\t-d | --directory  The directory to install Wordpress\n'
USAGE_MSG=${USAGE_MSG}$'\t-db | --database  The name of the database to create\n'
USAGE_MSG=${USAGE_MSG}$'\t-u | --user       The new SQL user\'s username\n'
USAGE_MSG=${USAGE_MSG}$'\t-p | --password   The new SQL user\'s password\n\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\t*  export  *\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\tUsage: $ ./wputil export -d=/site/dir -b=/backup/dir \'-db=dbname\'\n'
USAGE_MSG=${USAGE_MSG}$'\t-d | --directory  The directory where Wordpress resides\n'
USAGE_MSG=${USAGE_MSG}$'\t-b | --backup     The directory to save the compressed site\n'
USAGE_MSG=${USAGE_MSG}$'\t-db | --database  The name of the database to export\n'
USAGE_MSG=${USAGE_MSG}$'\t-dbox             This flag will tell the script to upload to dropbox\n\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\t*  import   *\n'
USAGE_MSG=${USAGE_MSG}$'\t*************\n'
USAGE_MSG=${USAGE_MSG}$'\tUsage: $ ./wputil import -d=/site/dir -b=/backup/dir \'-db=dbname\' \'-u=newuser\' \'-p=pass\'\n'
USAGE_MSG=${USAGE_MSG}$'\t-d | --directory  The directory where to import Wordpress site\n'
USAGE_MSG=${USAGE_MSG}$'\t-db | --database  The name of the database to import\n'
USAGE_MSG=${USAGE_MSG}$'\t-b | --backup     The backup file to import\n'
USAGE_MSG=${USAGE_MSG}$'\t-dbox             Use the backup stored on dropbox and ignore -b\n'
USAGE_MSG=${USAGE_MSG}$'\t-u | --user       The new SQL user\'s username\n'
USAGE_MSG=${USAGE_MSG}$'\t-p | --password   The new SQL user\'s password\n'

# Install function
function wputil_install()
{
    EXPECTED_ARGS=4

    # Make sure argument count matches what we expect
    if [[ $ARG_COUNT -ne $EXPECTED_ARGS ]]; then
        echo "$USAGE_MSG"
        exit
    fi

    # Set all arguments
    for i in $ARGS
    do
        case $i in
            -d=*|--directory=* )
                INSTALL_DIR=${i#*=}
                if [[ ! $INSTALL_DIR = '/' ]]; then
                    INSTALL_DIR=${INSTALL_DIR%/}
                fi
                ;;
            -db=*|--database=* )
                DB_NAME=${i#*=}
                ;;
            -u=*|--user=* )
                MYSQL_SITE_USER=${i#*=}
                ;;
            -p=*|--password=* )
                MYSQL_SITE_PASS=${i#*=}
                ;;
        esac
    done

    # validate arguments by checking if null or empty
    if [[ ( -z $INSTALL_DIR ) || ( ! -d $INSTALL_DIR ) ]]; then
        echo "$INSTALL_DIR is not a directory"
        exit
    elif [[ -z $DB_NAME ]]; then
        echo "Missing database name"
        exit
    elif [[ -z $MYSQL_SITE_USER ]]; then
        echo "Missing MYSQL username for new user"
        exit
    elif [[ -z $MYSQL_SITE_PASS ]]; then
        echo "Missing MYSQL password for new user"
        exit
    fi

    # Confirm all arguments are correct
    echo "Install dir: $INSTALL_DIR"
    echo "Database:    $DB_NAME"
    echo "User:        $MYSQL_SITE_USER"
    echo "Password:    $MYSQL_SITE_PASS"

    isCorrect="0"

    while [[ ( ! $isCorrect = "Y" ) && ( ! $isCorrect = "n" ) ]]
    do
        echo "Make sure everything is correct. [Y/n]"
        read isCorrect
    done

    if [[ $isCorrect = "n" ]]; then exit; fi

    # Download wordpress and unzip
    cd ${INSTALL_DIR}
    wget http://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz
    cp -a ${INSTALL_DIR}/wordpress/. ${INSTALL_DIR}
    rm ${INSTALL_DIR}/latest.tar.gz
    rm -r ${INSTALL_DIR}/wordpress

    # Create MySQL database and user
    QUERY="CREATE DATABASE ${DB_NAME};"
    QUERY=$QUERY"CREATE USER ${MYSQL_SITE_USER}@${MYSQL_HOST};"
    QUERY=$QUERY"SET PASSWORD FOR ${MYSQL_SITE_USER}@${MYSQL_HOST}= PASSWORD(\"${MYSQL_SITE_PASS}\");"
    QUERY=$QUERY"GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${MYSQL_SITE_USER}@${MYSQL_HOST} IDENTIFIED BY '${MYSQL_SITE_PASS}';"
    QUERY=$QUERY"FLUSH PRIVILEGES;"
    mysql -u $MYSQL_USER -p$MYSQL_PASS -e "$QUERY"
    echo "Created MySQL databse, user, and privleges"

    # Create the config file and update database, username, and password
    cp ${INSTALL_DIR}/wp-config-sample.php ${INSTALL_DIR}/wp-config.php
    sed -i "s/database_name_here/${DB_NAME}/g" ${INSTALL_DIR}/wp-config.php
    sed -i "s/username_here/${MYSQL_SITE_USER}/g" ${INSTALL_DIR}/wp-config.php
    sed -i "s/password_here/${MYSQL_SITE_PASS}/g" ${INSTALL_DIR}/wp-config.php
    echo "Done"
}

# export function
function wputil_export()
{
    EXPECTED_ARGS=3
    DROPBOX=false

    # Make sure argument count GREATER THAN or equal
    if [[ $ARG_COUNT -lt $EXPECTED_ARGS ]]; then
        echo "$USAGE_MSG"
        exit
    fi

    # Set all arguments
    for i in $ARGS
    do
        case $i in
            -d=*|--directory=* )
                SITE_DIR=${i#*=}
                if [[ ! $SITE_DIR = '/' ]]; then
                    SITE_DIR=${SITE_DIR%/}
                fi
                ;;
            -b=*|--backup=* )
                BACKUP_DIR=${i#*=}
                if [[ ! $BACKUP_DIR = '/' ]]; then
                    BACKUP_DIR=${BACKUP_DIR%/}
                fi
                ;;
            -db=*|--database=* )
                DB_NAME=${i#*=}
                ;;
            -dbox )
                DROPBOX=true
                ;;
        esac
    done

    # validate arguments by checking if null or empty
    if [[ ( -z $SITE_DIR ) || ( ! -d $SITE_DIR ) ]]; then
        echo "$SITE_DIR is not a directory"
        exit
    elif [[ ( -z $BACKUP_DIR ) || ( ! -d $BACKUP_DIR ) ]]; then
        echo "$BACKUP_DIR is not a directory"
        exit
    elif [[ -z $DB_NAME ]]; then
        echo "Missing database name"
        exit
    fi

    # Confirm all arguments are correct
    echo "Site Directory:    $SITE_DIR"
    echo "Backup Directory:  $BACKUP_DIR"
    echo "Database:          $DB_NAME"
    echo "Upload to DropBox: $DROPBOX"

    isCorrect="0"

    while [[ ( ! $isCorrect = "Y" ) && ( ! $isCorrect = "n" ) ]]
    do
        echo "Make sure everything is correct. Very large databases may take a long time to complete. [Y/n]"
        read isCorrect
    done

    if [[ $isCorrect = "n" ]]; then exit; fi

    cd $SITE_DIR
    mysqldump -u $MYSQL_USER -p$MYSQL_PASS $DB_NAME > DB_EXPORT.sql
    tar -C $(dirname $SITE_DIR) -zcvf ${BACKUP_DIR}/$(basename $SITE_DIR).${DATETIME}.tar.gz $(basename $SITE_DIR)
    cd $SITE_DIR
    rm DB_EXPORT.sql
    if [[ $DROPBOX = true ]]; then
        ${SCRIPT_DIR}/dropbox_uploader.sh upload ${BACKUP_DIR}/$(basename $SITE_DIR).${DATETIME}.tar.gz /
    fi
    echo "Done"
}

# import function
function wputil_import()
{
    EXPECTED_ARGS=5
    DROPBOX=false

    # Make sure argument count GREATER THAN or equal
    if [[ $ARG_COUNT -lt $EXPECTED_ARGS ]]; then
        echo "$USAGE_MSG"
        exit
    fi

    # Set all arguments
    for i in $ARGS
    do
        case $i in
            -d=*|--directory=* )
                IMPORT_DIR=${i#*=}
                if [[ ! $IMPORT_DIR = '/' ]]; then
                    IMPORT_DIR=${IMPORT_DIR%/}
                fi
                ;;
            -b=*|--backup=* )
                BACKUP_FILE=${i#*=}
                # Make sure backup is a tarball
                filename=$(basename "$BACKUP_FILE")
                extension="${filename##*.}"
                if [[ ! $extension = 'gz' ]]; then
                    echo "Backup file must be tar.gz"
                    exit
                fi
                ;;
            -db=*|--database=* )
                DB_NAME=${i#*=}
                ;;
            -dbox )
                DROPBOX=true
                ;;
            -u=*|--user=* )
                MYSQL_SITE_USER=${i#*=}
                ;;
            -p=*|--password=* )
                MYSQL_SITE_PASS=${i#*=}
                ;;
        esac
    done

    # validate arguments by checking if null or empty
    if [[ ( -z $IMPORT_DIR ) || ( ! -d $IMPORT_DIR ) ]]; then
        echo "$IMPORT_DIR is not a directory"
        exit
    elif [[ ( $DROPBOX = false ) && ( ( -z $BACKUP_FILE ) || ( ! -f $BACKUP_FILE ) ) ]]; then
        echo "$BACKUP_FILE is not a file"
        exit
    elif [[ -z $DB_NAME ]]; then
        echo "Missing database name"
        exit
    elif [[ -z $MYSQL_SITE_USER ]]; then
        echo "Missing MYSQL username for new user"
        exit
    elif [[ -z $MYSQL_SITE_PASS ]]; then
        echo "Missing MYSQL password for new user"
        exit
    fi

    # Confirm all arguments are correct
    echo "Import Directory:  $IMPORT_DIR"
    echo "Backup Directory:  $BACKUP_FILE"
    echo "Database:          $DB_NAME"
    echo "Upload to DropBox: $DROPBOX"

    isCorrect="0"

    while [[ ( ! $isCorrect = "Y" ) && ( ! $isCorrect = "n" ) ]]
    do
        echo "Make sure everything is correct. Very large databases may take a long time to complete. [Y/n]"
        read isCorrect
    done

    if [[ $isCorrect = "n" ]]; then exit; fi

    cd $IMPORT_DIR

    # get backup from dropbox or other location
    if [[ $DROPBOX = true ]]; then
        ${SCRIPT_DIR}/dropbox_uploader.sh download $BACKUP_FILE $IMPORT_DIR
    else
        cp $BACKUP_FILE $IMPORT_DIR
    fi

    # Extract the tarball
    tar -C $IMPORT_DIR -zxvf ${IMPORT_DIR}/$(basename $BACKUP_FILE)

exit

















    # Extract the folder
    cd $IMPORT_DIR

    tar -zxvf ${BACKUP_DIR}/$(basename $IMPORT_DIR).${DATETIME}.tar.gz $IMPORT_DIR

    # Create MySQL database and user
    QUERY="CREATE DATABASE ${DB_NAME};"
    QUERY=$QUERY"CREATE USER ${MYSQL_SITE_USER}@${MYSQL_HOST};"
    QUERY=$QUERY"SET PASSWORD FOR ${MYSQL_SITE_USER}@${MYSQL_HOST}= PASSWORD(\"${MYSQL_SITE_PASS}\");"
    QUERY=$QUERY"GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${MYSQL_SITE_USER}@${MYSQL_HOST} IDENTIFIED BY '${MYSQL_SITE_PASS}';"
    QUERY=$QUERY"FLUSH PRIVILEGES;"
    mysql -u $MYSQL_USER -p$MYSQL_PASS -e "$QUERY"
    echo "Created MySQL databse, user, and privleges"
    mysql -u $MYSQL_USER -p$MYSQL_PASS $DB_NAME < $(basename $IMPORT_DIR).sql
    echo "Successfully imported database"

    cd $IMPORT_DIR
    tar -zcvf ${BACKUP_DIR}/$(basename $IMPORT_DIR).${DATETIME}.tar.gz $IMPORT_DIR
    rm DB_EXPORT.sql
    if [[ $DROPBOX = true ]]; then
       ${SCRIPT_DIR}/dropbox_uploader.sh upload ${BACKUP_DIR}/$(basename $IMPORT_DIR).${DATETIME}.tar.gz /
    fi
    echo "Done"
}

# install dependency function
function install_dependencies()
{
    # If dropbox uploader does not exist, download and run it
    if [[ ! -f "${SCRIPT_DIR}/dropbox_uploader.sh" ]]; then
        cd ${SCRIPT_DIR}
        echo "Dropbox-Uploader not found!"
        echo $'Downloading Dropbox-Uploader:\n'
        curl "https://raw.githubusercontent.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh" -o dropbox_uploader.sh
        echo $'\nYou must configure Dropbox-Uploader then rerun ./wputil.sh'
        chmod +x dropbox_uploader.sh
        ./dropbox_uploader.sh
        echo "Please run ./wputil.sh again to continue"
        exit
    fi
}


# MAIN 

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
install_dependencies # Install any dependencies

# Look for method
FIRST_PARAM="$1"
shift
ARG_COUNT="$#"
ARGS="$@"
case $FIRST_PARAM in
    install )
        wputil_install
        exit
        ;;
    export )
        wputil_export
        exit
        ;;
    import )
        wputil_import
        exit
        ;;
    * ) # Default
        echo "$USAGE_MSG"
        exit
    ;;
esac
