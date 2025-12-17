#!/bin/bash

# Script for inotify watcher (https://github.com/klemens-u/Watcher-Python3)
# When a file is created/changed/deleted in the filesystem (e.g. over Samba),
# run nextcloud file scanning for the parent directory. Otherwise
# the updates would not be recognized by Nextcloud
# 
# Call with: watcher_nextcloud.sh watchedDirectory pathOfChangedFile
# E.g. /usr/local/bin/watcher_nextcloud.sh /srv/nextcloud/admin/files /srv/nextcloud/admin/files/foo.txt
#
# Output of this script is logged by watcher.py (by default to /var/log/watcher.log)
#
# (C) 2019-2025 by klemens.ullmann-marx@ull.at

# Enable strict error handling: exit on error (-e), treat unset variables as error (-u), 
# and fail pipeline if any command in a pipe fails, not just the last one (-o pipefail)
set -euo pipefail

# Configuration
NEXTCLOUD_DATA_DIR="/srv/nextcloud"
NEXTCLOUD_OCC_PATH="/var/www/nextcloud/occ"
NEXTCLOUD_WWW_USER="www-data"
# Set to true to enable debug output (e.g. occ files:scan details). 
DEBUG=TRUE

# Validate input arguments
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <watchedDirectory> <pathOfChangedFile>" >&2
    exit 1
fi

WATCHED_DIRECTORY="$1"
CHANGED_FILE_PATH="$2"

# Log detected activity with timestamp (captured by watcher.py)
echo "$(date +"%Y-%m-%d %H:%M:%S.%6N") $0: detected change in$WATCHED_DIRECTORY ($CHANGED_FILE_PATH) and will run Nextcloud file scan"

# Extract relative path from Nextcloud data directory for "occ files:scan"
# Example: /srv/nextcloud/admin/files => /admin/files
# Using parameter expansion to remove the prefix
SCAN_PATH="${WATCHED_DIRECTORY#$NEXTCLOUD_DATA_DIR}"

# Ensure SCAN_PATH starts with / (handles case where WATCHED_DIRECTORY equals NEXTCLOUD_DATA_DIR)
if [ "$SCAN_PATH" = "" ]; then
    SCAN_PATH="/"
fi

# Build Nextcloud file scan command
# --shallow = non recursive to be faster
if [ "$DEBUG" = true ]; then
    SCAN_COMMAND="sudo -u $NEXTCLOUD_WWW_USER /usr/bin/php $NEXTCLOUD_OCC_PATH files:scan -v --shallow --path=$SCAN_PATH"
    echo "$SCAN_COMMAND"
else
    SCAN_COMMAND="sudo -u $NEXTCLOUD_WWW_USER /usr/bin/php $NEXTCLOUD_OCC_PATH files:scan --quiet --shallow --path=$SCAN_PATH"
fi

# Execute Nextcloud file scan command
# Output goes to stdout/stderr and is captured by watcher.py
$SCAN_COMMAND
