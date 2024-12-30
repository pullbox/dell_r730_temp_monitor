#!/bin/bash

# Configuration
CPU_TEMP_SENSOR="Core 0" # Adjust based on your sensors output
MAX_TEMP=80              # Maximum temperature in Celsius
MIN_TEMP=30              # Minimum temperature in Celsius
IPMITOOL_CMD="ipmitool raw 0x30 0x30 0x02 0xff" # IPMI base command
LOG_FILE="/var/log/cpu_temp_monitor.log"


# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


# Set fan control to manual mode
set_manual_fan_control() {
  ipmitool raw 0x30 0x30 0x01 0x00
}

# Set fan control to automatic mode
set_automatic_fan_control() {
  ipmitool raw 0x30 0x30 0x01 0x01
}


# Fan Speed (%)	Hex Value
# 5%	0x05
# 10%	0x0A
# 15%	0x0F
# 20%	0x14
# 25%	0x19
# 30%	0x1E
# 35%	0x23
# 40%	0x28
# 45%	0x2D
# 50%	0x32
# 55%	0x37
# 60%	0x3C
# 65%	0x41
# 70%	0x46
# 75%	0x4B
# 80%	0x50
# 85%	0x55
# 90%	0x5A
# 95%	0x5F
# 100%	0x64

# Fan speed table based on temperature range
# Format: "MinTemp MaxTemp FanSpeed"
FAN_SPEED_TABLE=(
  "0 40 0x0f 15%" # 15% for temperatures 0-40°C
  "41 50 0x14 20%" # 20% for temperatures 41-50°C
  "51 55 0x23 25%" # 25% for temperatures 51-55°C
  "56 58 0x28 35%" # 35% for temperatures 56-58°C
  "59 60 0x32 50%" # 50% for temperatures 59-60°C
  "61 70 0x50 80%" # 80% for temperatures 61-70°C
  "71 80 0x64 100%" # 100% for temperatures 71-80°C
)

# Function to get the appropriate fan speed from the table
get_fan_speed_from_table() {
  local temp=$1
  for entry in "${FAN_SPEED_TABLE[@]}"; do
    local min_temp=$(echo "$entry" | awk '{print $1}')
    local max_temp=$(echo "$entry" | awk '{print $2}')
    local fan_speed=$(echo "$entry" | awk '{print $3}')
    local speed=$(echo "$entry" | awk '{print $4}')
    if (( temp >= min_temp && temp <= max_temp )); then
      echo "$fan_speed"
      log_message "Speed: $fan_speed $speed" 
    return
    fi
  done
  echo "0x19" # Default to 30% if no match
}

# Function to get the current CPU temperature
get_cpu_temps() {
  NEW_CPU1_TEMP=$(sensors | grep 'Package id 0:' | awk '{print $4}' | cut -c 2- | awk '{printf "%.0f\n", $1}')
  NEW_CPU2_TEMP=$(sensors | grep 'Package id 1:' | awk '{print $4}' | cut -c 2- | awk '{printf "%.0f\n", $1}')
  echo "$NEW_CPU1_TEMP $NEW_CPU2_TEMP"
  log_message "$NEW_CPU1_TEMP $NEW_CPU2_TEMP"
}


# Trap to set fan control to automatic if the script is stopped
trap set_automatic_fan_control EXIT


# Main loop
set_manual_fan_control # Enable manual control at the start

# Main loop
while true; do
  read cpu1_temp cpu2_temp <<< $(get_cpu_temps)
  if [[ -n $cpu1_temp && -n $cpu2_temp ]]; then
    avg_temp=$(( (cpu1_temp + cpu2_temp) / 2 ))
    fan_speed=$(get_fan_speed_from_table "$avg_temp")
    echo "CPU1: $cpu1_temp°C, CPU2: $cpu2_temp°C -> Avg: $avg_temp°C -> Fan Speed: $fan_speed"
    log_message "CPU1 Temp: $cpu1_temp°C, CPU2 Temp: $cpu2_temp°C -> Avg Temp: $avg_temp°C -> Fan Speed: $fan_speed"
    $IPMITOOL_CMD $fan_speed   
  else
    echo "Failed to read CPU temperature."
    log_message "Failed to read CPU temperature."
  fi
  sleep 20 # Adjust the interval as needed
done

