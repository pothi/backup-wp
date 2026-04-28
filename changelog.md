version: 6.2.1
    - date: 2026.04.28
    - better output / log info.

version: 6.2.0
    - date: 2026.04.21
    - automatic removal of temporary files created using mktemp
    - simplify log file name

version: 6.1.1
    - date: 2026.04.16
    - improve variable names
    - improve output info (log).

version: 6.1.0
    - date: 2026.04.10
    - keep server/user config on their own directory insider the domain data.
    - change the name of the database backup from db to db.sql.
    - improve formatting.

version: 6.0.0
    - date: 2026.04.08
    - take backups of server config (/etc) and some user config (~/.config, ~/.aws, ~/.wp-cli)
    - skip cron backups. Take cron backups to ~/.config/cron/ to include them in backups.
    - move up the variables to make them easier to find and change.

version: 5.8.2
    - date: 2026.03.31
    - better place for logs
    - improve PATH

version: 5.8.1
    - date: 2026.03.25
    - update Github raw URL
    - simpliied logic

version: 5.8.0
    - date: 2026.03.24
    - fix update logic
    - fix syntax checking if a variable is set.

version: 5.7.3
    - date: 2026.03.18
    - display run time.

version: 5.7.2
    - date: 2026.03.11
    - use 'type' in place of 'command'.

version: 5.7.1
    - date: 2025.12.01
    - fix issue with monthly backups

version: 5.7.0
    - date: 2025.11.11
    - fix issue with BCC email syntax

version: 5.6.1
    - date: 2025.10.14
    - fix the script name while updating the script.

version: 5.6.0
    - date: 2025.07.29
    - change variable names to lowercase.

version: 5.5.1
    - date: 2025.07.24
    - fix syntax for command `command` (previously bash syntax was used; not supported by fish)

version: 5.5.0
    - date: 2025.07.21
    - set PATH correctly
    - backup-files.fish: take a backup of cron as well.

version: 5.4.2
    - date: 2025.06.25
    - better docs.
    - bugfix on auto-update of backup-db.fish

version: 5.4.1
    - date: 2025.06.11
    - create ~/log and ~/backup folders

version: 5.4.0
    - date: 2025.03.06
    - bug fix for offsite-only-backup.
    - backward compatibility for fish version 3.3.1

version: 5.3.2
    - date: 2024.11.27
    - bug fix for auto-update

version: 5.3.1
    - date: 2024.11.27
    - bug fix for auto-update

version: 5.3.0
    - date: 2024.11.27
    - include version and update flags.
    - remove unused conflicting PATH variable

version: 5.2.1
    - date: 2024.11.26
    - better error messages

version: 5.2
    - date: 2024.11.20
    - include PATH

version: 5.1
    - date: 2024.11.18
    - option to include DBdump while taking files backup

version: 5.0
    - date: 2024.11.04
    - improve naming scheme
    - email alerts (upon failures)
    - improve docs.
    - same script to take full and partial files backup.
    - remove backup-full.fish, as it is incorporated in backup-files.fish

version: 4.0
    - date: 2024.10.08
    - switch to a standard fish function
    - replace BACKUP_PATH with DIR_NIGHTLY wherever possible.
    - replace WP_PATH with wp_root
    - new variable backup_type to dynamically generate BACKUP_PATH
    - remove the unused variable SITE

version: 3.0
    - date: 2024.10.05
    - Separate backup file name for weekly, monthly and offsite backups.
    - unique backup file name only for nightly backups.

