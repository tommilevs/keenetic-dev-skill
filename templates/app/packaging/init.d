#!/bin/sh
# init script for __APP__ (Entware). rc.unslung compatible: start/stop/restart/status.
ENABLED=yes
PROCS=__APP__
NAME=__APP__
BIN=/opt/bin/$NAME
CFG=/opt/etc/$NAME/config.json
LOG=/opt/var/$NAME/log
PIDF=/opt/var/run/$NAME.pid

mkdir -p "$LOG" /opt/var/run

start() {
  [ -x "$BIN" ] || { echo "$BIN is missing"; exit 1; }
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "$NAME is already running"
    return 0
  fi
  "$BIN" -config "$CFG" >>"$LOG/app.log" 2>&1 &
  echo $! > "$PIDF"
  sleep 1
  if kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "$NAME started"
  else
    echo "$NAME failed to start, see $LOG/app.log"
    exit 1
  fi
}

stop() {
  if [ -f "$PIDF" ]; then
    PID="$(cat "$PIDF")"
    kill "$PID" 2>/dev/null
    for _ in 1 2 3 4 5; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 1
    done
    kill -9 "$PID" 2>/dev/null
    rm -f "$PIDF"
  fi
  echo "$NAME stopped"
}

status() {
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "$NAME alive (pid $(cat "$PIDF"))"
  else
    echo "$NAME stopped"
    exit 3
  fi
}

case "$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 1; start ;;
  status)  status ;;
  *) echo "usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
