#!/bin/bash
# claude-access-enable — richtet einen temporären, eng begrenzten
# SSH/sudo-Zugang für Claude Code ein (System-User "claude").
#
# Usage: claude-access-enable [service ...]
#        claude-access-enable "<ssh-public-key>" [service ...]
#
# Nutzt standardmaessig einen festen, ueber Sessions hinweg wiederverwendeten
# Public Key (siehe DEFAULT_PUBKEY) -- kein Key-Parameter noetig, damit
# "sudo claude-access-enable <service>" jedes Mal ohne Rueckfrage
# funktioniert. Optional laesst sich der Key weiterhin explizit
# ueberschreiben, indem das erste Argument mit "ssh-"/"ecdsa-"/"sk-"
# beginnt (z.B. fuer eine Key-Rotation).
#
# Fuer jeden angegebenen Service werden NOPASSWD-sudo-Regeln fuer die
# ueblichen Diagnose-Befehle angelegt (systemctl status, journalctl,
# Config-/Unit-Dateien lesen, Datenverzeichnis auflisten/finden) --
# kein pauschaler Root-Zugriff. Ohne Service-Argumente gibt es nur den
# SSH-Login, keine sudo-Rechte.
set -euo pipefail

DEFAULT_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa3mK1PYQ2rxGMWuvt5n3RzzPjJzouKarDBFGY1hslu claude-code-persistent-temp-access"

if [[ $EUID -ne 0 ]]; then
    echo "Muss als root laufen (sudo)." >&2
    exit 1
fi

PUBKEY="$DEFAULT_PUBKEY"
if [[ $# -gt 0 && "$1" =~ ^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-) ]]; then
    PUBKEY="$1"
    shift
fi
SERVICES=("$@")

USER_NAME=claude
SUDOERS_FILE=/etc/sudoers.d/claude-temp-access

if ! id "$USER_NAME" &>/dev/null; then
    useradd --system --create-home --shell /bin/bash "$USER_NAME"
    echo "User '$USER_NAME' angelegt."
else
    echo "User '$USER_NAME' existiert bereits, Key/Rechte werden aktualisiert."
fi

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
echo "$PUBKEY" > "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"

usermod -aG systemd-journal "$USER_NAME" 2>/dev/null || true

TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT

for svc in "${SERVICES[@]}"; do
    {
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/systemctl status ${svc}*"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/journalctl -u ${svc}*"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/cat /etc/${svc}.env"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/cat /etc/default/${svc}"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/cat /usr/lib/systemd/system/${svc}.service"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/cat /etc/systemd/system/${svc}.service"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/ls -la /var/lib/${svc}"
        echo "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/find /opt /srv /home /var/lib -maxdepth 4 -iname *${svc}*"
    } >> "$TMP_SUDOERS"
done

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    echo "Kein Service angegeben -- es wird nur SSH-Zugang eingerichtet, kein sudo." >&2
fi

if [[ -s "$TMP_SUDOERS" ]]; then
    if visudo -cf "$TMP_SUDOERS"; then
        install -m 440 "$TMP_SUDOERS" "$SUDOERS_FILE"
        echo "sudoers-Regeln installiert: $SUDOERS_FILE"
    else
        echo "FEHLER: generierte sudoers-Datei ungueltig, nicht installiert." >&2
        exit 1
    fi
else
    rm -f "$SUDOERS_FILE"
fi

echo "Fertig. Zugang aktiv fuer: ${SERVICES[*]:-(nur SSH)}"
echo "Zum Beenden: claude-access-disable"
