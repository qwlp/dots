# Migrating an existing desktop

Use this when a machine is still on a revision from before the desktop theme
packages and live switching were added. The first switch changes GTK's user
stylesheets and makes Foot, Kitty, Quickshell, Neovim, and Emacs consume the
shared theme state, so do the migration while those applications can be
restarted.

## 1. Check and update the dotfiles checkout

Do not pull over machine-local changes. From the dotfiles checkout:

```sh
cd ~/.dotfiles
git status --short
git fetch origin
git log --oneline HEAD..origin/main
git pull --ff-only
```

If `git status` is not empty, commit or stash those changes first and resolve
them deliberately after the pull. The live-theme implementation first appears
in commit `f938995`.

The managed configs must still be linked from the checkout. At minimum, check
the consumers changed by this migration:

```sh
readlink -f ~/.config/quickshell
readlink -f ~/.config/foot
readlink -f ~/.config/kitty
readlink -f ~/.config/nvim
readlink -f ~/.config/emacs
```

Each configured path should resolve under `~/.dotfiles/shared/config/`. If this
desktop uses copied configs instead of links, redeploy them with its normal
dotfile linking command before continuing.

## 2. Preserve the current GTK customization

`theme-set` keeps a one-time copy of the pre-migration GTK CSS in
`~/.config/tsp-theme/gtk-legacy/`. Make an independent backup as well, so the
original desktop styling can be restored even after several switches:

```sh
backup_dir="$HOME/.local/state/tsp-theme/pre-live-migration"
mkdir -p "$backup_dir"
for version in 3.0 4.0; do
  destination="$backup_dir/gtk-$version.css"
  if [ -e "$HOME/.config/gtk-$version/gtk.css" ] && \
     [ ! -e "$destination" ]; then
    cp -a "$HOME/.config/gtk-$version/gtk.css" \
      "$destination"
  fi
done
```

The legacy stylesheet is used only by `naysayer`; the other packages replace
it with their own GTK base and managed override.

## 3. Bootstrap the shared state

Run this immediately after pulling, before restarting Foot or Kitty. Their new
configs include files through `~/.config/tsp-theme/current`, which this command
creates:

```sh
~/.config/quickshell/scripts/theme-set naysayer
```

This also creates:

- `~/.config/tsp-theme/current`, the stable package pointer used by apps
- `~/.config/quickshell/theme`, the Quickshell package pointer
- `~/.local/state/tsp-theme/name`, the selected theme name
- `~/.local/state/omarchy/current/background`, the selected wallpaper pointer

The setter tolerates missing optional applications. For the complete live
experience, `qs`/Quickshell and `awww` should be available; Kitty live reload
also requires the committed `allow_remote_control` and `listen_on` settings.

## 4. Restart the desktop session once

Log out of Niri and back in. This ensures Quickshell starts with the new theme
files and Foot, Kitty, Neovim, and Emacs load their new shared-theme adapters.
Later switches happen live and do not require another session restart.

After logging in, test both the direct setter and the visual picker:

```sh
~/.config/quickshell/scripts/theme-set aamis
~/.config/quickshell/scripts/theme-picker
```

Available ids are `naysayer`, `aamis`, `gruber-tsoding`, and `ginger-bill`.

## 5. One-time application setup

- **AyuGram:** open
  `~/.config/tsp-theme/ayugram.tdesktop-palette` once with the hidden
  `loadcolors` command and choose **Keep changes**. Its file watcher handles
  later switches.
- **Helium:** restart it after a switch. Its Chromium theme is loaded only at
  startup.
- **JetBrains IDEs:** choose the LAF named by the selected package's
  `theme.conf`. JetBrains has no live adapter here.
- **Existing GTK apps:** apps that ignore the settings notification may need a
  restart; new GTK processes use the selected theme.

## Verification and recovery

The selected id and both pointers should agree:

```sh
cat ~/.local/state/tsp-theme/name
readlink -f ~/.config/tsp-theme/current
readlink -f ~/.config/quickshell/theme
```

If a switch leaves the desktop inconsistent, rerun the setter with a known
theme and restart the affected application:

```sh
~/.config/quickshell/scripts/theme-set naysayer
```

To recover the pre-migration GTK CSS, first stop switching themes, then copy
the saved `gtk-3.0.css` and `gtk-4.0.css` from
`~/.local/state/tsp-theme/pre-live-migration/` back to their corresponding
`~/.config/gtk-*/gtk.css` paths. The automatic originals are also available
under `~/.config/tsp-theme/gtk-legacy/`.
