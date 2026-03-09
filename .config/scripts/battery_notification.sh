#!/bin/bash

LOW_BATTERY_THRESHOLD=99

while true; do
    STATUS=$(acpi -b | grep -o '[0-9]*%')
    BATTERY_LEVEL=$(echo "$STATUS" | sed 's/%//')
    IS_CHARGING=$(acpi -b | grep -o 'Charging')

    # Send low battery notification
    if [ "$BATTERY_LEVEL" -le "$LOW_BATTERY_THRESHOLD" ] && [ "$IS_CHARGING" = "" ]; then
        notify-send "Low Battery" "Battery is at $BATTERY_LEVEL%. Plug in your charger!"
        sleep 0.5
    fi
done
