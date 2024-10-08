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

