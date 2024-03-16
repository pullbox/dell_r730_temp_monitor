#!/bin/bash


LOG_FILE="/var/log/cpu_temp_monitor.log"

FAN_CURVE=( [0]=15 [35]=25 [40]=22 [42]=23 [43]=24 [44]=26 [45]=27 [46]=28 [48]=33 [49]=35 [50]=40 [55]=50 [60]=55 [80]=64 )

IPMIBASE="ipmitool raw 0x30 0x30"
FAN_CMD="$IPMIBASE 0x02 0xff"


# Initialize fan speed to 0
FAN_SPEED=0
# Initialize cpu temp to 0
CPU_TEMP=0


# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Loop indefinitely to monitor CPU temp
while true
do

 # read the CPU Temp
 NEW_CPU1_TEMP=$(sensors | grep 'Package id 0:' | awk '{print $4}' | cut -c 2- | awk '{printf "%.0f\n", $1}')
 NEW_CPU2_TEMP=$(sensors | grep 'Package id 1:' | awk '{print $4}' | cut -c 2- | awk '{printf "%.0f\n", $1}')

 CPU_TEMP=$NEW_CPU1_TEMP
 if [ $CPU_TEMP -lt $NEW_CPU2_TEMP  ]
 then
  CPU_TEMP=$NEW_CPU2_TEMP
 fi 
  log_message "CPU1 Temp: $NEW_CPU1_TEMP"
  log_message "CPU2 Temp: $NEW_CPU2_TEMP"

 # Find the fan speed for the current Temp

 for TEMP in "${!FAN_CURVE[@]}"
 do
  if [ $CPU_TEMP -ge $TEMP ]
  then
    NEW_FAN_SPEED=${FAN_CURVE[$TEMP]}
  else
    break
  fi
 done


 # Set Fan speed
 if [ $NEW_FAN_SPEED -ne $FAN_SPEED ]
 then
  log_message "Setting fan speed to $NEW_FAN_SPEED"
  $FAN_CMD $NEW_FAN_SPEED
  FAN_SPEED=$NEW_FAN_SPEED
 fi

 # Wait 10 seconds before checking again
 sleep 10
done


# Fan speed thresholds (adjust these values as needed)
LOW_TEMP_THRESHOLD=48
HIGH_TEMP_THRESHOLD=60

# Check if CPU temperatures exceed thresholds and adjust fan speed
if [ "$NEW_CPU1_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ] || [ "$NEW_CPU2_TEMP" -ge "$HIGH_TEMP_THRESHOLD" ]; then
    # Set fan speed to high
 #   ipmitool raw 0x30 0x30 0x02 0xff 0x32
    log_message "High CPU temperature detected. Fan speed set to high. 50%"
elif [ "$NEW_CPU1_TEMP" -ge "$LOW_TEMP_THRESHOLD" ] || [ "$NEW_CPU2_TEMP" -ge "$LOW_TEMP_THRESHOLD" ]; then
    # Set fan speed to medium
 #   ipmitool raw 0x30 0x30 0x02 0xff 0x28
    log_message "Moderate CPU temperature detected. Fan speed set to medium 40%."
else
    # Set fan speed to low
 #   ipmitool raw 0x30 0x30 0x02 0xff 0x19
    log_message "Normal CPU temperature detected. Fan speed set to low 25%."
fi

