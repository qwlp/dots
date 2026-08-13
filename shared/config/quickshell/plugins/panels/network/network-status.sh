#!/bin/sh

# Backend-neutral probe/actions for systems where Quickshell.Networking cannot
# expose the active connection (currently iwd without NetworkManager).
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

wifi_iface=
for phy in /sys/class/net/*/phy80211; do
  [ -e "$phy" ] || continue
  wifi_iface=${phy%/phy80211}
  wifi_iface=${wifi_iface##*/}
  break
done

case "${1:-status}" in
  networks)
    [ -n "$wifi_iface" ] || exit 0
    iwctl station "$wifi_iface" scan >/dev/null 2>&1 || true
    iwctl station "$wifi_iface" get-networks 2>/dev/null | strip_ansi |
      awk '
        /^[[:space:]]*>?[[:space:]]+[^-]/ && $0 !~ /Network name|Available networks/ {
          line=$0; connected=(line ~ /^[[:space:]]*>/ ? "true" : "false")
          sub(/^[[:space:]]*>?[[:space:]]+/, "", line)
          sub(/[[:space:]]+$/, "", line)
          n=split(line, fields, /[[:space:]][[:space:]]+/)
          if (n < 3) next
          signal=length(fields[n]) * 25; security=fields[n-1]
          name=fields[1]; for (i=2; i<n-1; i++) name=name "  " fields[i]
          printf "%s\t%s\t%s\t%s\n", connected, signal, security, name
        }'
    exit 0
    ;;
  power)
    [ -n "$wifi_iface" ] || exit 1
    iwctl device "$wifi_iface" set-property Powered "$2"
    exit $?
    ;;
esac

iface=$(ip -4 route show default 2>/dev/null | awk 'NR == 1 { print $5 }')

[ -n "$wifi_iface" ] && printf 'wifi_iface\t%s\n' "$wifi_iface"

if [ -n "$wifi_iface" ] && command -v iwctl >/dev/null 2>&1; then
  device=$(iwctl device "$wifi_iface" show 2>/dev/null | strip_ansi)
  powered=$(printf '%s\n' "$device" | sed -n 's/^.*Powered[[:space:]]*//p' | head -n 1)
  [ -n "$powered" ] && printf 'wifi_powered\t%s\n' "$powered"
fi

if [ -z "$iface" ] || [ ! -d "/sys/class/net/$iface" ]; then
  exit 0
fi

printf 'iface\t%s\n' "$iface"

if [ -e "/sys/class/net/$iface/phy80211" ] || [ -d "/sys/class/net/$iface/wireless" ]; then
  printf 'type\twifi\n'
  printf 'connected\ttrue\n'

  if command -v iwctl >/dev/null 2>&1; then
    station=$(iwctl station "$iface" show 2>/dev/null | sed 's/\033\[[0-9;]*m//g')
    ssid=$(printf '%s\n' "$station" | sed -n 's/^[[:space:]]*Connected network[[:space:]]*//p' | head -n 1)
    rssi=$(printf '%s\n' "$station" | sed -n 's/^[[:space:]]*RSSI[[:space:]]*\(-\{0,1\}[0-9][0-9]*\).*/\1/p' | head -n 1)
    freq=$(printf '%s\n' "$station" | sed -n 's/^[[:space:]]*Frequency[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)

    [ -n "$ssid" ] && printf 'ssid\t%s\n' "$ssid"
    [ -n "$freq" ] && printf 'freq\t%s\n' "$freq"
    if [ -n "$rssi" ]; then
      signal=$((2 * (rssi + 100)))
      [ "$signal" -lt 0 ] && signal=0
      [ "$signal" -gt 100 ] && signal=100
      printf 'signal\t%s\n' "$signal"
    fi
  fi
else
  printf 'type\tethernet\n'
  printf 'connected\ttrue\n'
fi

ip_addr=$(ip -4 -o address show dev "$iface" scope global 2>/dev/null | awk 'NR == 1 { print $4 }')
[ -n "$ip_addr" ] && printf 'ip\t%s\n' "$ip_addr"
gateway=$(ip -4 route show default dev "$iface" 2>/dev/null | awk 'NR == 1 { print $3 }')
[ -n "$gateway" ] && printf 'gateway\t%s\n' "$gateway"
[ -r "/sys/class/net/$iface/statistics/rx_bytes" ] && printf 'rx_bytes\t%s\n' "$(cat "/sys/class/net/$iface/statistics/rx_bytes")"
[ -r "/sys/class/net/$iface/statistics/tx_bytes" ] && printf 'tx_bytes\t%s\n' "$(cat "/sys/class/net/$iface/statistics/tx_bytes")"

if [ -n "$gateway" ]; then
  router_ping=$(ping -c 1 -W 1 "$gateway" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
  [ -n "$router_ping" ] && printf 'router_ping_ms\t%s\n' "$router_ping"
fi
internet_ping=$(ping -c 1 -W 1 1.1.1 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
[ -n "$internet_ping" ] && printf 'internet_ping_ms\t%s\n' "$internet_ping"
