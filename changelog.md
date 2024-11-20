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

