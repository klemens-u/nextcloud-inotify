#!/bin/bash

# Script for inotify watcher (https://github.com/klemens-u/Watcher-Python3)
# When a file is created/changed/deleted in the filesystem (e.g. over Samba)
# run nextcloud file scanning for the parent directory. Otherwise
# the updates would not be recognized by Nextcloud
# 
# Call with: watcher_nextcloud.sh watchedDirectory pathOfChangedFile
# E.g. /usr/local/bin/watcher_nextcloud.sh /srv/nextcloud/admin/files /srv/nextcloud/admin/files/foo.txt
#
# (C) 2019-2024 by klemens.ullmann-marx@ull.at

# Note: this logfile is gonna be huge! Use logging only for debugging.
LOGGING_ENABLED=true
LOG_FILE="/var/log/watcher_nextcloud.log"
NEXTCLOUD_DATA_DIR="/srv/nextcloud"

log_message() {
    if [ "$LOGGING_ENABLED" = true ]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

log_message "### Detected activity in $1 ($2)"
log_message "$(date)"

# Subtracting the nextcloud data directory to get the relative path needed for "occ files:scan"
# Example: $1 = "/srv/nextcloud/admin/files"  =>  "/admin/files" 
SCAN_PATH=$(echo $1 | sed "s#^$NEXTCLOUD_DATA_DIR##g")
SCAN_COMMAND="sudo -u www-data /usr/bin/php /var/www/nextcloud/occ files:scan -v --shallow --path=${SCAN_PATH}"

# Execute and optionally log the command output
if [ "$LOGGING_ENABLED" = true ]; then
    $SCAN_COMMAND | tee -a "$LOG_FILE"
else
    $SCAN_COMMAND
fi

