#!/bin/sh
# H323 Gateway Control Script
# Wrapper to call H323Service Python module via systemctl or direct execution

ACTION="$1"
GNUGK_BIN="/usr/local/sbin/gnugk"
GNUGK_CONFIG="/etc/h323/gnugk.conf"
GNUGK_LOG="/var/log/h323.log"
GNUGK_PID="/var/run/gnugk.pid"

case "$ACTION" in
    start)
        echo "Starting H323 gateway (gnugk)..."
        if [ -f "$GNUGK_BIN" ]; then
            # Start gnugk in background with config
            # $GNUGK_BIN -c "$GNUGK_CONFIG" -l "$GNUGK_LOG" &
            service gnugk start
            echo $! > "$GNUGK_PID"
            sleep 1
            exit 0
        else
            echo "Error: gnugk binary not found at $GNUGK_BIN"
            exit 1
        fi
        ;;
    stop)
        echo "Stopping H323 gateway (gnugk)..."
        if [ -f "$GNUGK_PID" ]; then
            PID=$(cat "$GNUGK_PID")
            if kill -0 "$PID" 2>/dev/null; then
                kill -TERM "$PID"
                # Wait for graceful shutdown
                for i in 1 2 3 4 5; do
                    if ! kill -0 "$PID" 2>/dev/null; then
                        break
                    fi
                    sleep 1
                done
                # Force kill if still running
                kill -KILL "$PID" 2>/dev/null
                rm -f "$GNUGK_PID"
            fi
        fi
        exit 0
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        exit $?
        ;;
    status)
        if [ -f "$GNUGK_PID" ]; then
            PID=$(cat "$GNUGK_PID")
            if kill -0 "$PID" 2>/dev/null; then
                echo "H323 gateway (gnugk) is running (PID: $PID)"
                exit 0
            fi
        fi
        echo "H323 gateway (gnugk) is not running"
        exit 1
        ;;
    apply_rules)
        echo "Applying H323 firewall rules..."
        /usr/local/opnsense/scripts/filter/apply_h323_rules.py
        exit $?
        ;;
    apply_runtime)
        echo "Applying H323 runtime configuration..."
        /usr/local/opnsense/scripts/h323/apply_h323.py
        exit $?
        ;;
    reconfigure)
        $0 apply_runtime || exit 1
        $0 apply_rules || exit 1
        $0 restart || exit 1
        exit 0
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|apply_rules|apply_runtime|reconfigure}"
        exit 1
        ;;
esac

exit 0
