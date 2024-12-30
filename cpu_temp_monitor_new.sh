#!/bin/bash

# Configuration
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


# Set fan speed to a specific percentage
set_fan_speed() {
  local speed=$1
  $IPMITOOL_CMD $speed
}

# Convert hex fan speed to percentage
convert_fan_speed_to_percent() {
  case $1 in
    0x05) echo "5%" ;;
    0x0A) echo "10%" ;;
    0x0F) echo "15%" ;;
    0x14) echo "20%" ;;
    0x19) echo "25%" ;;
    0x1E) echo "30%" ;;
    0x23) echo "35%" ;;
    0x28) echo "40%" ;;
    0x2D) echo "45%" ;;
    0x32) echo "50%" ;;
    0x37) echo "55%" ;;
    0x3C) echo "60%" ;;
    0x41) echo "65%" ;;
    0x46) echo "70%" ;;
    0x4B) echo "75%" ;;
    0x50) echo "80%" ;;
    0x55) echo "85%" ;;
    0x5A) echo "90%" ;;
    0x5F) echo "95%" ;;
    0x64) echo "100%" ;;
    *) echo "Unknown" ;;
  esac
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
  "0 40 0x0f" # 15% for temperatures 0-40°C
  "41 50 0x14" # 20% for temperatures 41-50°C
  "51 55 0x19" # 25% for temperatures 51-55°C
  "56 58 0x1E" # 30% for temperatures 56-58°C
  "59 60 0x28" # 35% for temperatures 59-60°C
  "61 65 0x2D" # 45% for temperatures 61-70°C
  "66 70 0x50" # 80% for temperatures 61-70°C
  "71 80 0x64" # 100% for temperatures 71-80°C
)

# Function to get the appropriate fan speed from the table
get_fan_speed_from_table() {
  local temp=$1
  for entry in "${FAN_SPEED_TABLE[@]}"; do
    local min_temp=$(echo "$entry" | awk '{print $1}')
    local max_temp=$(echo "$entry" | awk '{print $2}')
    local fan_speed=$(echo "$entry" | awk '{print $3}')
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


# Function to set fan speed to 50% at midnight for 1 minute
midnight_fan_speed() {
  while true; do
    current_time=$(date +"%H:%M")
    if [[ "$current_time" == "00:00" ]]; then
      log_message "Setting fan speed to 40% for 1 minute at midnight."
      set_fan_speed 0x28 # 40%
      sleep 60
      log_message "Resuming normal fan control after midnight adjustment."
    fi
    sleep 1
  done
}


# Main loop
set_manual_fan_control # Enable manual control at the start
log_message "Fan control set to manual mode"



# Start the midnight fan speed adjustment in the background
midnight_fan_speed &


# Main loop
while true; do
  read cpu1_temp cpu2_temp <<< $(get_cpu_temps)
  if [[ -n $cpu1_temp && -n $cpu2_temp ]]; then
    max_temp=$(( cpu1_temp > cpu2_temp ? cpu1_temp : cpu2_temp ))
    fan_speed=$(get_fan_speed_from_table "$max_temp")
    fan_speed_percent=$(convert_fan_speed_to_percent "$fan_speed")
    echo "CPU1: $cpu1_temp°C, CPU2: $cpu2_temp°C -> MAx: $max_temp°C -> Fan Speed: $fan_speed ($fan_speed_percent)"
    log_message "CPU1 Temp: $cpu1_temp°C, CPU2 Temp: $cpu2_temp°C -> Max Temp: $max_temp°C -> Fan Speed: $fan_speed ($fan_speed_percent)"
    $IPMITOOL_CMD $fan_speed   
  else
    echo "Failed to read CPU temperature."
    log_message "Failed to read CPU temperature."
  fi
  sleep 20 # Adjust the interval as needed
done

