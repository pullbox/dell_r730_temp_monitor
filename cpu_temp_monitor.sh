#!/bin/bash

# IPMI commands to get CPU temperatures
CPU1_TEMP=$(ipmitool sdr type temperature | grep '0Eh' | awk '{print $9}')
CPU2_TEMP=$(ipmitool sdr type temperature | grep '0Fh' | awk '{print $9}')


echo "CPU1 Temp: " $CPU1_TEMP
echo "CPU2 Temp: " $CPU2_TEMP


# Fan speed thresholds (adjust these values as needed)
LOW_TEMP_THRESHOLD=44
HIGH_TEMP_THRESHOLD=55

# Check if CPU temperatures exceed thresholds and adjust fan speed
if [ "$CPU1_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ] || [ "$CPU2_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ]; then
    # Set fan speed to high
    ipmitool raw 0x30 0x30 0x02 0xff 0x32
    echo "High CPU temperature detected. Fan speed set to high. 50%"
elif [ "$CPU1_TEMP" -ge "$LOW_TEMP_THRESHOLD" ] || [ "$CPU2_TEMP" -ge "$LOW_TEMP_THRESHOLD" ]; then
    # Set fan speed to medium
    ipmitool raw 0x30 0x30 0x02 0xff 0x28
    echo "Moderate CPU temperature detected. Fan speed set to medium 40%."
else
    # Set fan speed to low
    ipmitool raw 0x30 0x30 0x02 0xff 0x1E
    echo "Normal CPU temperature detected. Fan speed set to low 30%."
fi

