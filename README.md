# Detect file system changes for Nextcloud data

The following is a nice and efficent solution to inform Nextcloud about changes to files in the Nextcloud data directory.
A common usecase is the integration of SAMBA, so files can be accessed via network shares and Nextcloud.

The solution was tested with Ubuntu 22.04 Server, but should be easy to adapt for other Linux distributions.

## Problem

When a file is created/changed/deleted in the filesystem (e.g. over Samba) updates are not recognized by Nextcloud.
Running `occ files:scan` regularly is very I/O intensive and takes a long time, multiple minutes even for medium installation.

## Solution

Use Linux inotify to scan only the specific directory where the file change occured.

We'll use `watcher.py` as tool for that: https://github.com/klemens-u/Watcher-Python3

# Setup & Ops
- `vi /etc/sysctl.d/60-increase.inotify-maxuserwatches.conf`
```
# Increase for /usr/local/bin/watcher.py
fs.inotify.max_user_watches=65536   
```
- `sysctl --system`
  - To apply changes in sysctl
- `cat /proc/sys/fs/inotify/max_user_watches`
  - Check if setting was applied correctly
- `apt install python3-pyinotify`
- `wget https://raw.githubusercontent.com/klemens-u/Watcher-Python3/master/watcher.py --directory-prefix /usr/local/bin`
  - The inotify watcher script. This was forked multiple times. My version works with Python3 on Ubuntu 22.04.
- `wget https://raw.githubusercontent.com/klemens-u/nextcloud-inotify/main/watcher_nextcloud.sh --directory-prefix /usr/local/bin`
  - A script by me which is called by `watcher.py` which triggers `occ files:scan` with the specific path where the change occured.
  - Note: disable log in production. It get's huge!
- `chmod 700 /usr/local/bin/watcher*`
- `wget https://raw.githubusercontent.com/klemens-u/nextcloud-inotify/main/watcher.ini --directory-prefix /etc`
- `vi /etc/watcher.ini`
  - Adapt watcher configuration to your needs
- `vi /etc/rc.local`
```
# Start watcher.py during boot. Notifies Nextcloud about filesystem changes
watcher.py start
```

## Start / Stop / Debug
- `watcher.py stop`
  - Stop watching the nextcloud data dir. Important when copying large amounts of files.
- `watcher.py restart`
  - Restart after config change
- `tail -f /var/log/watcher.log`
  - View the main log
- `tail -f /var/log/watcher_nextcloud.log `
  - View the log of `watcher_nextcloud.sh`


## Rotate Watcher Logfiles
- `vi /etc/logrotate.d/watcher`
```
/var/log/*watcher.log {
        # Rotate daily
        daily

        # But only when at least 100K filesize
        minsize 100K

        # And do not rotate empty logfiles
        notifempty

        # Keep a high number of versions
        rotate 9999

        # Because we delete files after 1 month (to keep in monthly backups)
        maxage 31

        # Compress
        compress

        # Delay compression until the second rotation cycle
        delaycompress

        # Use date extension instead of numbers, good for hardlink backups
        dateext

        # ISO date format
        dateformat .%Y-%m-%d

        # Other wise logrotate complains: error: skipping "/var/log/XXX.log" because parent directory has insecure permissions (It's world writable or writable by group which is not "root") Set "su" directive in config file to tell logrotate which user/group should be used for rotation.
        su root root

        # Do not complain about missing logfiles
         missingok

        # Immediately create a new log file after rotation
        create 640 root adm
}
```


# Bonus: Install SAMBA

- `apt install samba`
- `vi /etc/samba/smb.conf `
```
# comment out the printers

...

# Share a subdirectory of user1's Nextcloud files with authentification
[files]
path = /srv/nextcloud/user1/files/projects
writeable = yes
browseable = yes
valid users = projects
force user = www-data
force group = www-data

# Public Share
[pictures]
path = /srv/nextcloud/admin/files/pictures
public = yes
writeable = yes
force user = www-data
force group = www-data
```

- `testparm`
  - Tests SAMBA config
- `service smbd restart`

### Create a "project" user
- `adduser projects`
- `smbpasswd -a projects`
- `passwd --lock projects `
  - disable unix login for security
 
### Misc
- `pdbedit -L -v`
  - List SAMBA users



