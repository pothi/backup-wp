#!/usr/bin/env fish

# set -l fish_trace non_empty_value

# requirements
# ~/log, ~/backups, ~/path/to/example.com/public

set ver 3.0

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
set backup_type full

set ext tar.gz
set prefix -$backup_type

set BACKUP_PATH $HOME/backups/$backup_type

# Variables defined later in the script
set script_name (status basename)
set fulldate (date +%F)
set timestamp (date +%F_%H-%M-%S)
set success_alert
set custom_email
set custom_wp_path
set BUCKET_NAME
set DOMAIN
set PUBLIC_DIR public
set sizeH
set dirs_to_exclude

set unique_backup
set backup_symlink
set backup_by_date

# get environment variables, if exists
# .envrc is in the following format
# export VARIABLE=value
# [ -f "$HOME/.envrc" ] && source ~/.envrc
# uncomment the following, if you use .env with the format "VARIABLE=value" (without export)
# if [ -f "$HOME/.env" ]; then; set -a; source ~/.env; set +a; fi

# Do something cool with "$@"... \o/

# Get example.com
set DOMAIN $argv[1]
set BUCKET_NAME $argv[2]

# Number of backups to keep
set NightlyBackupsToKeep 7
set WeeklyBackupsToKeep 4
set MonthlyBackupsToKeep 12

# echo Domain: $DOMAIN

set DIR_NIGHTLY $BACKUP_PATH/nightly
set DIR_WEEKLY $BACKUP_PATH/weekly
set DIR_MONTHLY $BACKUP_PATH/monthly

test -d ~/tmp || mkdir -p ~/tmp
test -d "$DIR_NIGHTLY" || mkdir -p "$DIR_NIGHTLY"
test -d "$DIR_WEEKLY" || mkdir -p "$DIR_WEEKLY"
test -d "$DIR_MONTHLY" || mkdir -p "$DIR_MONTHLY"

set BACKUP_PATH $DIR_NIGHTLY

# check for backup dir
if test ! -d "$BACKUP_PATH"
    echo "BACKUP_PATH is not found at $BACKUP_PATH. This script can't create it, either!"
    echo 'You may create it manually and re-run this script.'
    exit 1
end

command -v wp >/dev/null || { echo >&2 "wp cli is not found in $PATH. Exiting."; exit 1; }
command -v aws >/dev/null || { echo >&2 "[Warn]: aws cli is not found in \$PATH. Offsite backups will not be taken!"; }
command -v mail >/dev/null || echo >&2 "[Warn]: 'mail' command is not found in \$PATH; Email alerts will not be sent!"

# set alertEmail ${custom_email:-${BACKUP_ADMIN_EMAIL:-${ADMIN_EMAIL:-"root@localhost"}}}
set alertEmail "root@localhost"

# Define paths

set unique_backup $BACKUP_PATH/$DOMAIN$prefix-$timestamp.$ext
set backup_symlink $BACKUP_PATH/$DOMAIN$prefix-latest.$ext
set backup_by_date $DOMAIN$prefix-$fulldate.$ext

set WP_PATH $SITES_PATH/$DOMAIN/$PUBLIC_DIR
# [ -d "$WP_PATH" ] || { echo >&2 "WordPress is not found at ${WP_PATH}"; exit 1; }

echo; echo Script to take a backup of files excluding uploads folder!; echo
echo "$script_name started on... $(date +%c)"

# echo WordPress PATH: $WP_PATH

set db_dump $SITES_PATH/$DOMAIN/db.sql
# remove the previous DB dump, if exists
test -f "$db_dump"; and rm $db_dump
#------------- from db-script.sh --------------#
# take actual DB backup
# 2>/dev/null to suppress any warnings / errors
# wp --path="${WP_PATH}" transient delete --all
if ! wp --path="$WP_PATH" db export --no-tablespaces=true --add-drop-table "$db_dump"
    msg="$script_name - [Error] Something went wrong while taking DB dump!"
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'DB Dump Failure' "$alertEmail"
    # remove the empty backup file
    [ -f "$db_dump" ] && rm "$db_dump"
    exit 1
end
#------------- end of snippet from db-script.sh --------------#

##############################    Files backup specific code       ###########################

# path to be excluded from the backup
# no trailing slash, please
set exclude_base_path $DOMAIN/$PUBLIC_DIR

set -a dirs_to_exclude --exclude='*.log'
set -a dirs_to_exclude --exclude='*.gz'
set -a dirs_to_exclude --exclude='*.zip'
set -a dirs_to_exclude --exclude=$exclude_base_path/.git
set -a dirs_to_exclude --exclude=$exclude_base_path/wp-content/cache
set -a dirs_to_exclude --exclude=$exclude_base_path/wp-content/wflogs
set -a dirs_to_exclude --exclude='*.sql'
# need more? - just use the above format

# echo Directories to exclude...;echo
# printf %s\n $dirs_to_exclude
# echo $dirs_to_exclude

# exit

# set -l fish_trace on
tar hczf $unique_backup $dirs_to_exclude -C $SITES_PATH $DOMAIN
# set fish_trace off
if test $status -eq 0
    echo Local backup is successful.
else
    set msg "$script_name - [Error] Something went wrong while taking local backup!"
    printf "\n%s\n\n" "$msg"
    echo "$msg" | mail -s 'Backup Failure' "$alertEmail"
    [ -f "$unique_backup" ] && rm -f "$unique_backup"
    exit 1
end


############################## end of files backup specific code #############################

set sizeH $(du -h $unique_backup | awk '{print $1}')

[ -L "$backup_symlink" ] && rm "$backup_symlink"
ln -s "$unique_backup" "$backup_symlink"

# send the backup offsite
if [ "$BUCKET_NAME" ];
    aws s3 cp $unique_backup s3://$BUCKET_NAME/$DOMAIN/$backup_type/$backup_by_date --only-show-errors
    if test $status -eq 0
        set msg "Offsite backup is successful."
        printf "\n%s\n\n" "$msg"
        [ "$success_alert" ] && echo "$script_name - $msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    else
        set msg "$script_name - [Error] Something went wrong while taking offsite backup."
        printf "\n%s\n\n" "$msg"
        echo "$msg" | mail -s 'Offsite Backup Info' "$alertEmail"
    end
end

# Weekly backup - Mondays
if test 1 -eq "$(date +%u)"
    cp $unique_backup $DIR_WEEKLY/$backup_by_date
end

# Monthly backup - 1st of each month
if test 1 -eq "$(date +%e)"
    cp $unique_backup $DIR_MONTHLY/$backup_by_date
end

# Auto delete backups
find -L $BACKUP_PATH/ -type f -iname "$DOMAIN$prefix-*" -mtime +$NightlyBackupsToKeep               -exec rm {} \;
find -L $DIR_WEEKLY/  -type f -iname "$DOMAIN$prefix-*" -mtime +$(math $WeeklyBackupsToKeep x 7)    -exec rm {} \;
find -L $DIR_MONTHLY/ -type f -iname "$DOMAIN$prefix-*" -mtime +$(math $MonthlyBackupsToKeep x 31)  -exec rm {} \;

echo Backup Folder: $BACKUP_PATH
echo Latest backup: $unique_backup
echo "Backup size:   $sizeH"

echo "$script_name ended on... $(date +%c)"
