#!/bin/bash

NGINX_LOG_DIR="/var/log/nginx"
ACCESS_LOG="${NGINX_LOG_DIR}/access.log"
ERROR_LOG="${NGINX_LOG_DIR}/error.log"
ROTATED_LOG_DIR="${NGINX_LOG_DIR}/rotated_logs"

mkdir -p $ROTATED_LOG_DIR

rotate_logs() {
    if [ -f $ACCESS_LOG ]; then
        TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
        mv $ACCESS_LOG $ROTATED_LOG_DIR/access.log.$TIMESTAMP
        echo "Access log rotated: $ACCESS_LOG -> $ROTATED_LOG_DIR/access.log.$TIMESTAMP"
    fi

    if [ -f $ERROR_LOG ]; then
        TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
        mv $ERROR_LOG $ROTATED_LOG_DIR/error.log.$TIMESTAMP
        echo "Error log rotated: $ERROR_LOG -> $ROTATED_LOG_DIR/error.log.$TIMESTAMP"
    fi

    touch $ACCESS_LOG
    touch $ERROR_LOG

    chmod 640 $ACCESS_LOG
    chmod 640 $ERROR_LOG
    chown root:adm $ACCESS_LOG
    chown root:adm $ERROR_LOG

    if [ -f /var/run/nginx.pid ]; then
        kill -USR1 $(cat /var/run/nginx.pid)
        echo "Nginx reloaded."
    fi
}

monitor_logs() {
    tail -n 100 $ERROR_LOG | grep -i "critical\|error\|warn" > /tmp/nginx_error_alert.log

    if [ -s /tmp/nginx_error_alert.log ]; then
        echo "Critical Nginx errors detected!" | mail -s "Nginx Critical Error Alert" admin@yourdomain.com
        echo "Critical errors found in Nginx logs, email sent to admin."
    else
        echo "No critical errors found in Nginx logs."
    fi
}

check_disk_space() {

    DISK_USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

    if [ $DISK_USAGE -gt 80 ]; then
        echo "Disk usage is above 80%, rotation skipped. Current usage: $DISK_USAGE%" | mail -s "Disk Space Alert" admin@yourdomain.com
        echo "Disk space is above 80%, log rotation skipped."
        exit 1
    else
        echo "Disk space usage is at ${DISK_USAGE}%, safe to proceed with log rotation."
    fi
}

check_disk_space
rotate_logs
monitor_logs
