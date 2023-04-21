#!/bin/sh
# Made by Jack'lul <jacklul.github.io>
#
# Ensure that WPS is disabled on the router
#
# Based on:
#  https://www.snbforums.com/threads/asus-rt-ac87u-stepped-into-the-382-branch-d.44227/#post-376642
#

#shellcheck disable=SC2155

CRON_MINUTE=0
CRON_HOUR=0

readonly SCRIPT_NAME="$(basename "$0" .sh)"
readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly SCRIPT_CONFIG="$(dirname "$0")/$SCRIPT_NAME.conf"
if [ -f "$SCRIPT_CONFIG" ]; then
    #shellcheck disable=SC1090
    . "$SCRIPT_CONFIG"
fi

case "$1" in
    "run")
        if [ "$(nvram get wl0_wps_mode)" != "disabled" ] || [ "$(nvram get wps_enable)" != "0" ] || [ "$(nvram get wps_enable_x)" != "0" ]; then
            [ "$(awk -F '.' '{print $1}' /proc/uptime)" -lt "300" ] && sleep 60 # delay when freshly booted

            nvram set wl0_wps_mode=disabled
            nvram set wps_enable=0
            nvram set wps_enable_x=0
            nvram commit

            logger -s -t "$SCRIPT_NAME" "WPS has been disabled"
            service restart_wireless
        fi
    ;;
    "start")
        cru a "$SCRIPT_NAME" "$CRON_MINUTE $CRON_HOUR * * * $SCRIPT_PATH run"

        "$SCRIPT_PATH" run &
    ;;
    "stop")
        cru d "$SCRIPT_NAME"
    ;;
    *)
        echo "Usage: $0 run|start|stop"
        exit 1
    ;;
esac