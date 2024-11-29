#!/bin/bash

# Set backup repository path
BACKUP_REPO=/home/venator/Documents/Borg


# Function to check Arch news with interactive bypass
check_arch_news() {
    # Display Arch news
    echo "Checking Arch Linux News:"
    informant print

    # Ask user to confirm upgrade safety
    read -p "Have you reviewed the news and are ready to proceed with upgrade? (y/n): " user_confirmation

    # Process user response
    if [[ "$user_confirmation" =~ ^[Yy]$ ]]; then
        return 0  # Proceed with upgrade
    else
        echo "Upgrade cancelled by user."
        exit 1
    fi
}

# Function to perform system backup with timeout
perform_system_backup() {
    echo "Starting system backup..."

    # Timeout after 2 hours (7200 seconds)
    timeout 7200 borg create -v --stats \
        "$BACKUP_REPO::system-{now:%Y-%m-%d}" \
        /home \
        /etc \
        /var \
        --exclude '/home/*/.cache' \
        --exclude '/home/venator/Downloads' \
        --exclude '/var/cache' 2>&1 | tee /tmp/borg_backup.log

    # Check backup exit status
    BACKUP_STATUS=${PIPESTATUS[0]}
    if [ $BACKUP_STATUS -eq 124 ]; then
        echo "Backup timed out after 30 minutes"
        exit 1
    elif [ $BACKUP_STATUS -ne 0 ]; then
        echo "Backup failed. Check /tmp/borg_backup.log for details"
        exit 1
    fi

    # Prune old backups (keep last 7 daily, 4 weekly, 6 monthly)
    borg prune -v --list \
        "$BACKUP_REPO" \
        --keep-daily=7 \
        --keep-monthly=6 \
        --keep-yearly=1
}

# Function to clean system
clean_system() {
    # Clear journald logs
    sudo journalctl --vacuum-time=3d

    # Clear tmp files
    sudo find /tmp -type f -atime +7 -delete

    # Empty trash for current and other users
    rm -rf ~/.local/share/Trash/* ~/.trash/*
    rm -rf /home/*/.local/share/Trash/* /home/*/.trash/*
}

# Function to handle system upgrade
perform_system_upgrade() {
    # Clear package manager caches
    sudo pacman -Sc
    paru -Sc
    yay -Sc

    # Perform system upgrade
    sudo pacman -Syu
    paru -Syu
}

# Main script execution
main() {
    # Check Arch news before proceeding
    check_arch_news

    # Perform system cleanup
    clean_system

    # Perform system backup
    perform_system_backup

    # Perform system upgrade
    perform_system_upgrade
}

# Run main function
main
