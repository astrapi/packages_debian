#!/bin/bash
# claude-access-disable — entfernt den temporären Zugang aus
# claude-access-enable wieder vollständig (User + sudoers-Regeln).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Muss als root laufen (sudo)." >&2
    exit 1
fi

USER_NAME=claude
SUDOERS_FILE=/etc/sudoers.d/claude-temp-access

rm -f "$SUDOERS_FILE"
echo "sudoers-Regeln entfernt."

if id "$USER_NAME" &>/dev/null; then
    pkill -u "$USER_NAME" 2>/dev/null || true
    userdel -r "$USER_NAME" 2>/dev/null || userdel "$USER_NAME"
    echo "User '$USER_NAME' entfernt."
else
    echo "User '$USER_NAME' existierte nicht (mehr)."
fi
