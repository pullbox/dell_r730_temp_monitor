#!/bin/bash


LOG_FILE="/var/log/cpu_temp_monitor.log"

# IPMI commands to get CPU temperatures
CPU1_TEMP=$(ipmitool sdr type temperature | grep '0Eh' | awk '{print $9}')
CPU2_TEMP=$(ipmitool sdr type temperature | grep '0Fh' | awk '{print $9}')

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


log_message "CPU1 Temp: $CPU1_TEMP"
log_message "CPU2 Temp: $CPU2_TEMP"


# Fan speed thresholds (adjust these values as needed)
LOW_TEMP_THRESHOLD=44
HIGH_TEMP_THRESHOLD=55

# Check if CPU temperatures exceed thresholds and adjust fan speed
if [ "$CPU1_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ] || [ "$CPU2_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ]; then
    # Set fan speed to high
    ipmitool raw 0x30 0x30 0x02 0xff 0x32
    log_message "High CPU temperature detected. Fan speed set to high. 50%"
elif [ "$CPU1_TEMP" -ge "$LOW_TEMP_THRESHOLD" ] || [ "$CPU2_TEMP" -ge "$LOW_TEMP_THRESHOLD" ]; then
    # Set fan speed to medium
    ipmitool raw 0x30 0x30 0x02 0xff 0x28
    log_message "Moderate CPU temperature detected. Fan speed set to medium 40%."
else
    # Set fan speed to low
    ipmitool raw 0x30 0x30 0x02 0xff 0x19
    log_message "Normal CPU temperature detected. Fan speed set to low 25%."
fi

