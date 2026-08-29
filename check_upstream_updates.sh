#!/usr/bin/env bash
# Liest nvchecker.toml aus, vergleicht jedes Ergebnis mit der aktuell in der
# jeweiligen PKGBUILD stehenden pkgver und bumpt bei einer echten,
# neueren Version pkgver/pkgrel. nvchecker selbst aendert nichts -- das
# macht ausschliesslich dieses Skript.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

current_pkgver() { bash -c "source '$1/PKGBUILD'; echo \$pkgver"; }

CHANGED=()
FAILURES=0

while IFS= read -r line; do
  event="$(jq -r '.event' <<<"$line")"
  pkg="$(jq -r '.name' <<<"$line")"

  if [[ "$event" != "updated" && "$event" != "up-to-date" ]]; then
    echo "::warning::$pkg: Upstream-Check fehlgeschlagen (event=$event)." >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  new="$(jq -r '.version' <<<"$line")"

  # Generischer Format-Schutz: nur reine, punktgetrennte Zahlen akzeptieren
  # (passt auf alle unsere Pakete) -- faengt eine kaputte Regex-/API-Antwort
  # ab, bevor sie ueberhaupt zum Versionsvergleich kommt.
  if [[ ! "$new" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "::warning::$pkg: '$new' sieht nicht wie eine echte Version aus, uebersprungen." >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  cur="$(current_pkgver "$pkg")"
  if [[ "$new" == "$cur" ]]; then
    echo "$pkg: aktuell ($cur)"
    continue
  fi

  # Nie eine nicht tatsaechlich hoehere Version uebernehmen (zusaetzlicher
  # Schutz vor kaputten/unerwarteten Antworten).
  higher="$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -n1)"
  if [[ "$higher" != "$new" ]]; then
    echo "::warning::$pkg: $new ist nicht neuer als $cur, uebersprungen." >&2
    continue
  fi

  echo "$pkg: $cur -> $new"
  sed -i "s/^pkgver=.*/pkgver=$new/" "$pkg/PKGBUILD"
  sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkg/PKGBUILD"
  CHANGED+=("$pkg: $cur -> $new")
done < <(nvchecker -c nvchecker.toml --logger=json --json-log-fd=1 2>/dev/null)

[[ ${#CHANGED[@]} -gt 0 ]] && python3 build_index.py

{
  echo "changed<<EOF_CHANGED"
  printf '%s\n' "${CHANGED[@]}"
  echo "EOF_CHANGED"
  echo "failures=$FAILURES"
} >>"${GITHUB_OUTPUT:-/dev/null}"

exit 0 # Skript selbst nie fehlschlagen lassen -- der Workflow entscheidet, ob rot
