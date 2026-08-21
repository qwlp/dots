# Desktop themes

For a machine upgrading from the older fixed-theme configuration, follow the
[desktop migration guide](MIGRATION.md) before running the picker.

Each directory is a self-contained theme package. `backgrounds/` contains its
wallpapers and provides the visual switcher preview. `colors.toml` is the
canonical 16-color palette, `shell.toml` contains Quickshell semantic tokens,
`foot.ini` and `kitty.conf` are app-native terminal fragments, and `theme.conf`
names adapters that cannot be derived faithfully from a palette. Kitty reads
the selected package through the stable `current` link; `theme-set` also pushes
the fragment to running remote-control-enabled Kitty instances.

`scripts/theme-set <id>` atomically moves both
`~/.config/tsp-theme/current` and `~/.config/quickshell/theme` to a package,
writes `~/.local/state/tsp-theme/name`, and asks running applications to
reload. The selected background is applied by `awww` and mirrored to
`~/.local/state/omarchy/current/background` for Quickshell. Applications should
consume one of these stable interfaces instead of
reading another application's config.

`helium-theme/manifest.json` is a full Chromium theme used by Brave Origin Beta.
`theme-set` copies it to the stable `~/.config/tsp-theme/brave-theme` directory
for the browser's next launch. This applies exact toolbar, omnibox, tab, and
sidebar colors without interrupting a running browser.

`ayugram.tdesktop-palette` is copied to a stable managed path. Load it once
with AyuGram's hidden `loadcolors` command and choose **Keep changes**; its
native file watcher then applies all later theme switches live. Chat wallpaper
is separate AyuGram state and is not controlled by palette files.

Older revisions used Chromium's generated-color policy. Keep its file writable
so `theme-set` can clear it before loading the exact extension theme:

```sh
sudo install -d -m 0755 /etc/brave/policies/managed
sudo install -o "$USER" -g "$(id -gn)" -m 0644 /dev/null \
  /etc/brave/policies/managed/tsp-theme-color.json
~/.config/quickshell/scripts/theme-set "$(command cat ~/.local/state/tsp-theme/name)"
```

The last command clears that policy and copies the active full theme. Restart
Brave manually when convenient to apply it. `brave://policy` should show no
`BrowserThemeColor` value.

The first GTK switch saves pre-existing styles under
`~/.config/tsp-theme/gtk-legacy/`. This machine's legacy GTK 4 stylesheet is a
full Naysayer theme, so it is layered only for Naysayer; other themes start
from their selected GTK base and native `gtk.css` fragment.

## Adding a theme

1. Copy an existing package and edit its palette and semantic shell roles.
2. Add its id to `theme_ids` in `scripts/theme-picker` to choose its ordering.
3. Add native assets only where palette generation is insufficient. `gtk.css`
   is installed as a managed override for both GTK 3 and GTK 4. Emacs
   themes live in `~/.config/emacs/themes`; Neovim consumes the palette by
   default; GTK uses `gtk_theme`; JetBrains uses `jetbrains_theme` as metadata
   for its adapter.
4. Run `scripts/theme-set <id>` to test without opening the picker.

## IntelliJ / JetBrains

JetBrains themes are plugins/LAFs, not a supported live palette endpoint.
`jetbrains_theme` deliberately records the desired LAF without rewriting
`options/laf.xml` behind a running IDE (which commonly overwrites that file on
exit). Naysayer maps to the already installed `naysayer88 (exp ui)` plugin;
Aamis currently maps to Darcula. Select the matching LAF once inside the IDE,
or add a future IDE-side plugin that watches `~/.local/state/tsp-theme/name`.

The package structure follows the useful part of Omarchy themes: one portable
palette plus optional native app fragments. It does not depend on Omarchy or
make one application's file the global source of truth.
