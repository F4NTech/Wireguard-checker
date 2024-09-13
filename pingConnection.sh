#!/bin/bash

# Function to get the current timestamp
get_timestamp() {
    date +"[%Y-%m-%d %H:%M:%S]"
}

# Define the target host or IP address
target_host="10.66.66.1"

# Define the time limit (in seconds) for the script to run
time_limit=3600  # 1 hour = 3600 seconds

# Define log retention period (in days)
log_retention_days=30

# Get the current timestamp
start_time=$(date +%s)

# Log file path
log_file="auto_log"

# Function to clean up old log entries
clean_up_logs() {
    # Get the current date
    current_date=$(date +%Y-%m-%d)

    # Find and delete log entries older than 30 days
    awk -v retention_days="$log_retention_days" -v current_date="$current_date" '
    BEGIN {
        split(current_date, curr, "-")
        curr_year = curr[1]
        curr_month = curr[2]
        curr_day = curr[3]
    }
    {
        # Extract date from the log line in the format [YYYY-MM-DD]
        if (match($0, /\[([0-9]{4})-([0-9]{2})-([0-9]{2})/, date)) {
            log_year = date[1]
            log_month = date[2]
            log_day = date[3]

            # Calculate the difference in days between log date and current date
            log_timestamp = mktime(log_year " " log_month " " log_day " 00 00 00")
            curr_timestamp = mktime(curr_year " " curr_month " " curr_day " 00 00 00")

            age_in_days = int((curr_timestamp - log_timestamp) / 86400)

            # Only print lines that are newer than the retention period
            if (age_in_days < retention_days) {
                print $0
            }
        }
    }' "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
}

# Redirect all output to auto_log file with timestamps
exec > >(while read line; do echo "$(get_timestamp) $line"; done | tee -a "$log_file") 2>&1

# Clean up logs at the start of the script
clean_up_logs

while true; do
    # Check if it's time to restart WireGuard (based on elapsed time)
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ $elapsed_time -ge $time_limit ]; then
        # Restart Wireguard
        echo -e "Restarting Wireguard !"
        systemctl restart wg-quick@wg0
        sleep 2
        echo -e "Wireguard restart successful."
        
        # Ping target host
        if ping -c 1 -W 10 $target_host; then
            echo "Ping to $target_host successful."
        else
            echo -e "Cannot ping $target_host. The host may be unreachable. Rebooting the system."
            systemctl restart wg-quick@wg0
            sudo reboot
        fi

        # Reset start time for the next interval
        start_time=$(date +%s)
    fi

    # Sleep for 1 second before the next iteration
    sleep 1
done
