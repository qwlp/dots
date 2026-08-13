#!/bin/sh
set -eu

mode=${1:-}
if [ "$mode" = "--meta" ] || [ "$mode" = "--password" ]; then shift; fi
requested_iface=${1:-}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

iface=$requested_iface
[ -n "$iface" ] || iface=$(ip -4 route show default 2>/dev/null | awk 'NR == 1 { print $5 }')
[ -n "$iface" ] || { echo "No active network interface" >&2; exit 1; }
[ -e "/sys/class/net/$iface/phy80211" ] || [ -d "/sys/class/net/$iface/wireless" ] || {
  echo "The active connection is not Wi-Fi" >&2
  exit 1
}

ssid=
security=
password=

# NetworkManager is authoritative only when it actually owns this interface.
if command -v nmcli >/dev/null 2>&1 && nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null |
    awk -F: -v dev="$iface" '$1 == dev && $2 == "wifi" && $3 == "connected" { found=1 } END { exit !found }'; then
  connection=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -n 1)
  ssid=$(nmcli -g 802-11-wireless.ssid connection show "$connection" 2>/dev/null | head -n 1)
  key_mgmt=$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$connection" 2>/dev/null | head -n 1)
  password=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show "$connection" 2>/dev/null | head -n 1)
  case "$key_mgmt" in
    ''|none) security=nopass ;;
    *sae*) security=WPA ;;
    *wpa*|*psk*) security=WPA ;;
    *) security=WPA ;;
  esac
else
  command -v iwctl >/dev/null 2>&1 || { echo "Neither NetworkManager nor iwd is available" >&2; exit 1; }
  station=$(iwctl station "$iface" show 2>/dev/null | strip_ansi)
  ssid=$(printf '%s\n' "$station" |
    sed -n 's/^[[:space:]]*Connected network[[:space:]]*//p' |
    sed 's/[[:space:]]*$//' |
    head -n 1)
  [ -n "$ssid" ] || { echo "Wi-Fi is not connected" >&2; exit 1; }

  station_security=$(printf '%s\n' "$station" |
    sed -n 's/^[[:space:]]*Security[[:space:]]*//p' |
    sed 's/[[:space:]]*$//' |
    head -n 1)
  case "$station_security" in
    ''|Open|open|None|none) security=nopass ;;
    *) security=WPA ;;
  esac

  # iwd deliberately does not expose saved secrets over D-Bus. Its profile is
  # normally root-only. Prefer direct/passwordless access, then ask polkit to
  # authorize one narrowly-scoped sed read; Quickshell's polkit agent presents
  # that authentication in the shell.
  profile=
  for suffix in psk open; do
    candidate="/var/lib/iwd/$ssid.$suffix"
    if [ -r "$candidate" ]; then profile=$candidate; break; fi
    if command -v sudo >/dev/null 2>&1 && sudo -n test -r "$candidate" 2>/dev/null; then profile=$candidate; break; fi
  done
  case "$security:$profile" in
    nopass:*) ;;
    *.psk)
      if [ -r "$profile" ]; then
        password=$(sed -n 's/^Passphrase=//p' "$profile" | head -n 1)
      else
        password=$(sudo -n sed -n 's/^Passphrase=//p' "$profile" 2>/dev/null | head -n 1)
      fi
      ;;
    WPA:)
      candidate="/var/lib/iwd/$ssid.psk"
      if command -v pkexec >/dev/null 2>&1; then
        password=$(pkexec /usr/bin/sed -n 's/^Passphrase=//p' "$candidate" | head -n 1) || {
          echo "Authorization to read the saved iwd password was denied" >&2
          exit 1
        }
      else
        echo "Cannot read the saved iwd profile for $ssid" >&2
        exit 1
      fi
      ;;
    *) echo "Cannot read the saved iwd profile for $ssid" >&2; exit 1 ;;
  esac
fi

if [ "$mode" = "--password" ]; then
  [ -n "$password" ] || { echo "This network has no readable saved password" >&2; exit 1; }
  printf '%s\n' "$password"
  exit 0
fi

[ -n "$ssid" ] || { echo "Could not determine the Wi-Fi name" >&2; exit 1; }
if [ "$security" != nopass ] && [ -z "$password" ]; then
  echo "The saved Wi-Fi password is not readable" >&2
  exit 1
fi
command -v qrencode >/dev/null 2>&1 || { echo "qrencode is required to share Wi-Fi" >&2; exit 1; }

escape_wifi() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/;/\\;/g; s/,/\\,/g; s/:/\\:/g'; }
payload="WIFI:T:$security;S:$(escape_wifi "$ssid");"
[ "$security" = nopass ] || payload="$payload""P:$(escape_wifi "$password");"
payload="$payload;"

[ "$mode" = "--meta" ] && printf 'meta\t%s\t%s\t%s\n' "$iface" "$security" "$ssid"
# XPM is the portable text format supported by qrencode. At one pixel per
# module its F/B rows map directly to the QML renderer's 1/0 matrix.
qrencode -t XPM -s 1 -m 2 -o - "$payload" | awk '
  /\/\* pixels \*\// { pixels=1; next }
  pixels && /^"[FB]+"[,}]?;?$/ {
    row=$0; sub(/^"/, "", row); sub(/"[,}]?;?$/, "", row)
    gsub(/F/, "1", row); gsub(/B/, "0", row); print row
  }
'
