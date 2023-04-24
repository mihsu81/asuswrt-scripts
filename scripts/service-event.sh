#!/bin/sh
# Made by Jack'lul <jacklul.github.io>
#
# Execute commands when specific service events occurs
#
# Implements basic service-event script handler from AsusWRT-Merlin:
#  https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts
# There is no guarantee that this script will run before the event happens.
#

#shellcheck disable=SC2155

TARGET_SCRIPT="/jffs/scripts/service-event"
SYSLOG_FILE="/tmp/syslog.log"
SLEEP=1

readonly SCRIPT_NAME="$(basename "$0" .sh)"
readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly SCRIPT_CONFIG="$(dirname "$0")/$SCRIPT_NAME.conf"
if [ -f "$SCRIPT_CONFIG" ]; then
    #shellcheck disable=SC1090
    . "$SCRIPT_CONFIG"
fi

#shellcheck disable=SC2009
PROCESS_PID="$(ps | grep "$SCRIPT_NAME.sh run" | grep -v grep | awk '{print $1}')"

case "$1" in
    "run")
        [ -n "$PROCESS_PID" ] && [ "$(echo "$PROCESS_PID" | wc -l)" -gt 2 ] && { echo "Already running!"; exit 1; }
        [ ! -f "$SYSLOG_FILE" ] && { logger -s -t "$SCRIPT_NAME" "Syslog log file does not exist: $SYSLOG_FILE"; exit 1; }
        [ ! -f "$TARGET_SCRIPT" ] && { logger -s -t "$SCRIPT_NAME" "Target script does not exist: $TARGET_SCRIPT"; exit 1; }
        [ ! -x "$TARGET_SCRIPT" ] && { logger -s -t "$SCRIPT_NAME" "Target script is not executable!"; exit 1; }

        set -e

        logger -s -t "$SCRIPT_NAME" "Started service event monitoring..."
        
        LAST_LINE="$(wc -l < "$SYSLOG_FILE")"
        LAST_LINE="$((LAST_LINE+1))"

        while true; do
            TOTAL_LINES="$(wc -l < "$SYSLOG_FILE")"
            if [ "$TOTAL_LINES" -lt "$((LAST_LINE-1))" ]; then
                logger -s -t "$SCRIPT_NAME" "Log file has been rotated, resetting line pointer..."
                LAST_LINE=1
                continue
            fi
            
            NEW_LINES="$(tail "$SYSLOG_FILE" -n "+$LAST_LINE")"

            if [ -n "$NEW_LINES" ]; then
                MATCHING_LINES="$(echo "$NEW_LINES" | grep -En 'rc_service.*notify_rc' || echo '')"

                if [ -n "$MATCHING_LINES" ]; then
                    LAST_LINE_OLD=$LAST_LINE

                    IFS="$(printf '\n\b')"
                    for NEW_LINE in $MATCHING_LINES; do
                        LINE_NUMBER="$(echo "$NEW_LINE" | cut -f1 -d:)"
                        LAST_LINE="$((LAST_LINE_OLD+LINE_NUMBER))"

                        EVENTS="$(echo "$NEW_LINE" | awk -F 'notify_rc ' '{print $2}')"

                        if [ -n "$INIT" ]; then
                            OLDIFS=$IFS
                            IFS=';'
                            for EVENT in $EVENTS; do
                                if [ -n "$EVENT" ]; then
                                    EVENT_ACTION="$(echo "$EVENT" | cut -d'_' -f1)"
                                    EVENT_TARGET="$(echo "$EVENT" | cut -d'_' -f2-)"

                                    logger -s -t "$SCRIPT_NAME" "Running $TARGET_SCRIPT (args: $EVENT_ACTION $EVENT_TARGET)"
                                    sh "$TARGET_SCRIPT" "$EVENT_ACTION" "$EVENT_TARGET" &
                                fi
                            done
                            IFS=$OLDIFS
                        fi
                    done
                else
                    TOTAL_LINES="$(echo "$NEW_LINES" | wc -l)"
                    LAST_LINE="$((LAST_LINE+TOTAL_LINES))"
                fi
            fi

            [ -z "$INIT" ] && INIT=1

            sleep "$SLEEP"
        done
    ;;
    "init-run")
        cru d "$SCRIPT_NAME"

        [ -z "$PROCESS_PID" ] && nohup "$SCRIPT_PATH" run >/dev/null 2>&1 &
    ;;
    "start")
        [ -f "/usr/sbin/helper.sh" ] && { logger -s -t "$SCRIPT_NAME" "Merlin firmware detected, using this script is redundant!"; exit 1; }

        [ -z "$PROCESS_PID" ] && cru a "$SCRIPT_NAME" "*/1 * * * * $SCRIPT_PATH init-run"
    ;;
    "stop")
        cru d "$SCRIPT_NAME"

        [ -n "$PROCESS_PID" ] && kill "$PROCESS_PID"
    ;;
    "restart")
        sh "$SCRIPT_PATH" stop
        sh "$SCRIPT_PATH" start
    ;;
    *)
        echo "Usage: $0 run|start|stop|restart"
        exit 1
    ;;
esac