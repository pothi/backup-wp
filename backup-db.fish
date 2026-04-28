#!/usr/bin/env fish

# set -l fish_trace non_empty_value

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

set ver 6.2.1

### Variables - Please do not add trailing slash in the PATHs

# a passphrase for encryption, in order to being able to use almost any special characters use ""
# it's best to configure it in ~/.envrc file
set passphrase

# the script assumes your sites are stored like ~/sites/example.com, ~/sites/example.net, ~/sites/example.org and so on.
# if you have a different pattern, such as ~/app/example.com, please change the following to fit the server environment!
set sites_path {$HOME}/sites

# it could be public_html on some installations.
set public_dir public

# Number of backups to keep
set NightlyBackupsToKeep 7
set WeeklyBackupsToKeep 4
set MonthlyBackupsToKeep 12

#-------- Do NOT Edit Below This Line --------#

# create necessary directories
test -d ~/backups || mkdir -p ~/backups
test -d ~/log || mkdir -p ~/log

set backup_type db

set ext sql.gz
set prefix -$backup_type

set backups_folder $HOME/backups/$backup_type

# Variables defined later in the script
set script_name (status basename)
set fulldate (date +%F)
set timestamp (date +%F_%H-%M-%S)
set bucket_name
set domain
set sizeH

set unique_backup
set backup_symlink
set backup_by_date

# echo Domain: $domain

set dir_nightly $backups_folder/nightly
set dir_weekly $backups_folder/weekly
set dir_monthly $backups_folder/monthly

set alertEmails
set wp_root

set time_start
set time_end

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

    set domain $argv[1]

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
    end

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
    # 'status filename' - prints the script name including the path to it.
    set -l local_script (status filename)
    test -d ~/backups; or mkdir -p ~/backups
    # echo Current Script: $local_script
    # echo Script Name: $script_name

    # get the remote version & keep it in a temporary file
    set --global upstream_script (mktemp)
    trap 'rm "$upstream_script"' EXIT INT TERM
    # echo "Temp Remote Script: $upstream_script"
    curl -sSL -o $upstream_script https://raw.githubusercontent.com/pothi/backup-wp/refs/heads/main/$script_name

    # display the version info
    set -l upstream_version (fish $upstream_script -v)
    echo Local Version: $ver

    if test $ver != $upstream_version
        echo Upstream Version: $upstream_version
	    printf '%-72s' 'Taking a backup of this script into ~/backups dir'
	    cp $local_script ~/backups/(status basename)-$ver
	    echo done.

	    printf '%-72s' "Updating..."
	    # final steps
	    cp $upstream_script $local_script
	    echo done.
    else
	    echo Nothing to update.
    end
end

function __backup_db_bootstrap
    test -d ~/tmp || mkdir -p ~/tmp
    test -d "$dir_nightly" || mkdir -p "$dir_nightly"
    test -d "$dir_weekly" || mkdir -p "$dir_weekly"
    test -d "$dir_monthly" || mkdir -p "$dir_monthly"

    # Define paths

    set unique_backup $dir_nightly/$domain$prefix-$timestamp.$ext
    set backup_symlink $dir_nightly/$domain$prefix-latest.$ext
    set backup_by_date $domain$prefix-$fulldate.$ext

    set wp_root $sites_path/$domain/$public_dir
    # [ -d "$wp_root" ] || { echo >&2 "WordPress is not found at ${wp_root}"; exit 1; }

    ### Some standard checks ###
    # check for backup dir
    if test ! -d "$dir_nightly"
        echo >&2 "dir_nightly is not found at $dir_nightly This script can't create it, either!"
        echo >&2 You may create it manually and re-run this script.
        exit 1
    end

    set -x PATH ~/bin ~/.local/bin /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin
    test -d /snap/bin; and set -a PATH /snap/bin

    type --query wp ; or begin; echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; end
    command -q aws ; or begin; echo >&2 "[Warn]: aws cli is not found in $PATH. Offsite backups will not be taken!"; end
    type -q mail ; or  echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

    ### Actual Script Starts here...
    echo # Beginning of output
    # echo "$script_name started on... $(date +%c)"
    echo "Backup started on $(date +%c)"
    echo
    set time_start (date +%s)

end

function __backup_db_local
    # take actual DB backup
    # 2>/dev/null to suppress any warnings / errors
    # wp --path="$wp_root" transient delete --all
    echo Please hold on while backup is taken.
    if test -n "$passphrase"
        set unique_backup "$unique_backup".gpg
        wp --path="$wp_root" db export --no-tablespaces=true --add-drop-table - | gzip | gpg --symmetric --passphrase "$passphrase" --batch -o "$unique_backup"
    else
        wp --path="$wp_root" db export --no-tablespaces=true --add-drop-table - | gzip > "$unique_backup"
    end
    if test $status -eq 0
        echo Local backup is successful.
        echo
    else
        set msg "$script_name - [Error] Something went wrong while taking local backup!"
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Backup Failure' -b "$alertEmails" root@localhost
        [ -f "$unique_backup" ] && rm -f "$unique_backup"
        exit 1
    end

    set sizeH $(du -h $unique_backup | awk '{print $1}')

    [ -L "$backup_symlink" ] && rm "$backup_symlink"
    ln -s "$unique_backup" "$backup_symlink"
end

function __backup_db_offsite -a bucket_name
    # send the backup offsite
    aws s3 cp $unique_backup s3://$bucket_name/$domain/$backup_type/$backup_by_date --only-show-errors
    if test $status -eq 0
        set msg "Offsite backup is successful."
        printf "\n%s\n\n" "$msg"
        if set -q success_alert
            echo "$script_name - $msg" | mail -s 'Offsite Backup Info' -b "$alertEmails" root@localhost
        end
    else
        set msg "$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' -b "$alertEmails" root@localhost
    end
end

function __backup_db_cleanup
    # Weekly backup - Mondays
    if test 1 -eq "$(date +%u)"
        cp $unique_backup $dir_weekly/$backup_by_date
        echo Weekly backup is taken.
        echo
    end

    # Monthly backup - 1st of each month
    if test 1 -eq "$(date +%e)"
        cp $unique_backup $dir_monthly/$backup_by_date
        echo Monthly backup is taken.
        echo
    end

    # Auto delete backups
    find -L $dir_nightly/ -type f -iname "$domain$prefix-*" -mtime +$NightlyBackupsToKeep               -exec rm {} \;
    find -L $dir_weekly/  -type f -iname "$domain$prefix-*" -mtime +$(math $WeeklyBackupsToKeep x 7)    -exec rm {} \;
    find -L $dir_monthly/ -type f -iname "$domain$prefix-*" -mtime +$(math $MonthlyBackupsToKeep x 31)  -exec rm {} \;

    # Display some info about the backup.
    echo Backup Folder: $dir_nightly
    echo Latest backup: $unique_backup
    echo
    echo "Backup size:   $sizeH"

    set time_end (date +%s)
    set runtime (math $time_end - $time_start)
    set runtime_minutes (math -s0 $runtime / 60)
    set runtime_seconds (math $runtime % 60)
    echo Execution time: $runtime_minutes minutes $runtime_seconds seconds.
    echo

    # echo "$script_name ended on... $(date +%c)"
    # echo # end of output
end

backup-db $argv 2>&1 | tee -a ~/log/(status basename | awk -F. '{print $1}').log

# vim:fileencoding=utf-8:foldmethod=marker
