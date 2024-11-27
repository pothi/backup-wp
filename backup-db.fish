#!/usr/bin/env fish

# set -l fish_trace non_empty_value

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

set ver 5.3.0

### Variables - Please do not add trailing slash in the PATHs

# a passphrase for encryption, in order to being able to use almost any special characters use ""
# it's best to configure it in ~/.envrc file
set PASSPHRASE

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
set SITES_PATH {$HOME}/sites

# it could be public_html on some installations.
set PUBLIC_DIR public

#-------- Do NOT Edit Below This Line --------#

#TODO: create ~/log and ~/backups if they don't exist

set backup_type db

set ext sql.gz
set prefix -$backup_type

set backups_folder $HOME/backups/$backup_type

# Variables defined later in the script
set script_name (status basename)
set fulldate (date +%F)
set timestamp (date +%F_%H-%M-%S)
set BUCKET_NAME
set DOMAIN
set sizeH

set unique_backup
set backup_symlink
set backup_by_date

# Number of backups to keep
set NightlyBackupsToKeep 7
set WeeklyBackupsToKeep 4
set MonthlyBackupsToKeep 12

# echo Domain: $DOMAIN

set DIR_NIGHTLY $backups_folder/nightly
set DIR_WEEKLY $backups_folder/weekly
set DIR_MONTHLY $backups_folder/monthly

set alertEmails
set wp_root

function backup-db -d 'Create a DB dump and optionally store it offsite.'
    argparse --name=backup-db 'h/help' 'b/bucket=' 'x/exclude_uploads' 'o/only_offsite' 'e/email=' 's/success' 'v/version' 'u/update' -- $argv
    or return

    if set -q _flag_help
        __backup_db_print_help
        return 0
    end

    if set -q _flag_version
        __backup_print_version
        return 0
    end

    if set -q _flag_update
        __backup_update
        return 0
    end

    if not set -q argv[1]
        # if no arguments given (min requirement is example.com)
        __backup_db_print_help
        return 1
    end

    set DOMAIN $argv[1]

    if set -q _flag_email
        set alertEmails $_flag_email
    end

    if set -q _flag_success
        set success_alert yes
    end

    # actual script begins here
    begin
        __backup_db_bootstrap
        __backup_db_local

        if set -q _flag_bucket
            __backup_db_offsite $_flag_bucket
        end

        # set -l fish_trace non_empty_value
        __backup_db_cleanup
    end 2>&1 | tee -a ~/log/backup-$backup_type.log

end # end of backup-db as a function

function __backup_db_print_help
    printf '%s\n\n' "Take a database backup"

    printf 'Usage: %s [-b <bucket_name>] [-e <email-address>] [-s] [-p <WP path>] [-v] [-h] example.com\n\n' "$script_name"

    printf '\t%s\t%s\n' "-b, --bucket" "Name of the bucket for offsite backup (default: none)"
    printf '\t%s\t%s\n' "-e, --email" "Email/s to send success/failure alerts in addition to root"
    printf '\t%s\t%s\n' "-s, --success" "Alert on successful (offsite) backup (default: alert on failures)"
    printf '\t%s\t%s\n' "-p, --path" "Path to WP files (default: ~/sites/example.com/public)"
    printf '\t%s\t%s\n' "-v, --version" "Prints the version info"
    printf '\t%s\t%s\n' "-u, --update" "Update if a new version is available."
    printf '\t%s\t%s\n' "-h, --help" "Prints help"

    printf "\nFor more info, changelog and documentation... https://github.com/pothi/backup-wp\n"
end

function __backup_print_version
    echo $ver
end

function __backup_update
    # TODO: Skip update upon error or if there is no new version
    echo "Updating this script..."
    set current_script $(pwd)/$(status basename)
    mkdir -p ~/backups &>/dev/null
    cp $current_script ~/backups/$(status basename)-$ver
    set remote_script $(mktemp)
    echo "Temp Remote Script: $remote_script"
    curl -sSL -o $remote_script https://github.com/pothi/backup-wp/raw/refs/heads/main/backup-files.fish
    chmod +x $remote_script
    echo "Current Version: $ver"
    echo "Remote Version: $(fish remote_script -v)"
    cp $remote_script $current_script
    rm $remote_script
    echo Done.
end

function __backup_db_bootstrap
    test -d ~/tmp || mkdir -p ~/tmp
    test -d "$DIR_NIGHTLY" || mkdir -p "$DIR_NIGHTLY"
    test -d "$DIR_WEEKLY" || mkdir -p "$DIR_WEEKLY"
    test -d "$DIR_MONTHLY" || mkdir -p "$DIR_MONTHLY"

    # Define paths

    set unique_backup $DIR_NIGHTLY/$DOMAIN$prefix-$timestamp.$ext
    set backup_symlink $DIR_NIGHTLY/$DOMAIN$prefix-latest.$ext
    set backup_by_date $DOMAIN$prefix-$fulldate.$ext

    set wp_root $SITES_PATH/$DOMAIN/$PUBLIC_DIR
    # [ -d "$wp_root" ] || { echo >&2 "WordPress is not found at ${wp_root}"; exit 1; }

    ### Some standard checks ###
    # check for backup dir
    if test ! -d "$DIR_NIGHTLY"
        echo >&2 "DIR_NIGHTLY is not found at $DIR_NIGHTLY This script can't create it, either!"
        echo >&2 You may create it manually and re-run this script.
        exit 1
    end

    command -v wp >/dev/null || begin; echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; end
    command -v aws >/dev/null || begin; echo >&2 "[Warn]: aws cli is not found in $PATH. Offsite backups will not be taken!"; end
    command -v mail >/dev/null || echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

    ### Actual Script Starts here...
    echo # Beginning of output
    echo "$script_name started on... $(date +%c)"

end

function __backup_db_local
    # take actual DB backup
    # 2>/dev/null to suppress any warnings / errors
    # wp --path="$wp_root" transient delete --all
    if test -n "$PASSPHRASE"
        set unique_backup "$unique_backup".gpg
        wp --path="$wp_root" db export --no-tablespaces=true --add-drop-table - | gzip | gpg --symmetric --passphrase "$PASSPHRASE" --batch -o "$unique_backup"
    else
        wp --path="$wp_root" db export --no-tablespaces=true --add-drop-table - | gzip > "$unique_backup"
    end
    if test $status -eq 0
        echo Local backup is successful.
    else
        set msg "$script_name - [Error] Something went wrong while taking local backup!"
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Backup Failure' --append=Bcc:"$alertEmails" root@localhost
        [ -f "$unique_backup" ] && rm -f "$unique_backup"
        exit 1
    end

    set sizeH $(du -h $unique_backup | awk '{print $1}')

    [ -L "$backup_symlink" ] && rm "$backup_symlink"
    ln -s "$unique_backup" "$backup_symlink"
end

function __backup_db_offsite -a BUCKET_NAME
    # send the backup offsite
    aws s3 cp $unique_backup s3://$BUCKET_NAME/$DOMAIN/$backup_type/$backup_by_date --only-show-errors
    if test $status -eq 0
        set msg "Offsite backup is successful."
        printf "\n%s\n\n" "$msg"
        if set -q success_alert
            echo "$script_name - $msg" | mail -s 'Offsite Backup Info' --append=Bcc:"$alertEmails" root@localhost
        end
    else
        set msg "$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' --append=Bcc:"$alertEmails" root@localhost
    end
end

function __backup_db_cleanup
    # Weekly backup - Mondays
    if test 1 -eq "$(date +%u)"
        cp $unique_backup $DIR_WEEKLY/$backup_by_date
        echo Weekly backup is taken.
    end

    # Monthly backup - 1st of each month
    if test 1 -eq "$(date +%e)"
        cp $unique_backup $DIR_MONTHLY/$backup_by_date
        echo Monthly backup is taken.
    end

    # Auto delete backups
    find -L $DIR_NIGHTLY/ -type f -iname "$DOMAIN$prefix-*" -mtime +$NightlyBackupsToKeep               -exec rm {} \;
    find -L $DIR_WEEKLY/  -type f -iname "$DOMAIN$prefix-*" -mtime +$(math $WeeklyBackupsToKeep x 7)    -exec rm {} \;
    find -L $DIR_MONTHLY/ -type f -iname "$DOMAIN$prefix-*" -mtime +$(math $MonthlyBackupsToKeep x 31)  -exec rm {} \;

    # Display some info about the backup.
    echo Backup Folder: $DIR_NIGHTLY
    echo Latest backup: $unique_backup
    echo "Backup size:   $sizeH"

    echo "$script_name ended on... $(date +%c)"
    echo # end of output
end

backup-db $argv
