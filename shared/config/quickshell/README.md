# Full Quickshell bar for Niri

This is the full panel-based shell ported to Niri. The default bar includes:

- Niri workspaces and the active window
- clock and MPRIS media controls
- system tray
- Bluetooth discovery, pairing and device control through BlueZ
- Wi-Fi scanning, connection, password entry and saved-network control through NetworkManager
- PipeWire output/input selection, volume controls and per-application mixing
- battery status and power-profile selection

The active configuration is `config.json`. User changes made through the shell
are stored in `~/.config/quickshell/niri-shell.json`.

## Run

```sh
quickshell -p /home/tsp/.config/quickshell
```

Add this to `~/.config/niri/config.kdl` to start it with Niri:

```kdl
spawn-at-startup "quickshell" "--no-duplicate" "-p" "/home/tsp/.config/quickshell"
```

The original unmodified tree remains recoverable at
`/home/tsp/projects/probe/omarchyprobe/quickshell-omarchy-backup`.
