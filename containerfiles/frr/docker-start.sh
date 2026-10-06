#!/bin/bash
# Start FRR by reading the enabled daemons list from /etc/frr/daemons
# and passing them to watchfrr, which runs in foreground monitoring mode.
set -e

ENABLED=""
for d in zebra bgpd ospfd ospf6d ripd ripngd isisd staticd bfdd; do
    if grep -qE "^${d}=yes" /etc/frr/daemons 2>/dev/null; then
        ENABLED="$ENABLED $d"
    fi
done
ENABLED="${ENABLED# }"

if [ -z "$ENABLED" ]; then
    echo "ERROR: No daemons enabled in /etc/frr/daemons" >&2
    exit 1
fi

echo "Starting FRR daemons: $ENABLED"
exec /usr/libexec/frr/watchfrr $ENABLED
