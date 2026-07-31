# Migrating `~/org` from MEGA FUSE to MEGA Sync

This guide replaces a MEGA FUSE mount at `/home/tsp/org` with a normal local
Btrfs directory synchronized in the background with the MEGA cloud folder
`/org`.

The result is:

```text
Before: Emacs -> MEGA FUSE `/home/tsp/org` -> network/cloud
After:  Emacs -> local Btrfs `/home/tsp/org` <-> MEGA background sync <-> `/org`
```

In the before state, saving can block Emacs while the FUSE filesystem performs
remote I/O. In the after state, Emacs completes its write against Btrfs and
MEGAcmd uploads it independently.

## Instructions for Codex

Perform this as a stateful migration, not as a blind command list. Inspect the
machine before changing it, preserve the complete mounted directory, and stop
if the paths or MEGA account differ from the assumptions in this guide. Do not
delete the safety snapshot after migration.

Do not overwrite unrelated changes in the dotfiles repository. The systemd
service must remain in the repository and be symlinked into the user systemd
directory.

## Expected starting state

- MEGAcmd is installed and logged in.
- `/home/tsp/org` is a persistent MEGA FUSE mount of the remote `/org` folder.
- The dotfiles repository is `/home/tsp/.dotfiles`.
- The service source is:
  `/home/tsp/.dotfiles/shared/config/systemd/user/megacmd.service`.
- Its runtime link is:
  `/home/tsp/.config/systemd/user/megacmd.service`.

Confirm the state without modifying anything:

```bash
mega-version
mega-whoami
mega-fuse-show
mega-sync
findmnt -T /home/tsp/org -o TARGET,SOURCE,FSTYPE,OPTIONS
git -C /home/tsp/.dotfiles status --short
```

The initial `findmnt` result should identify `fuse.megafs`. Record any existing
normal sync configurations and do not disturb unrelated ones.

## 1. Quiesce Org activity

Close Org buffers on this device, or exit Emacs. Do not edit `/org` from
another device during the migration. Check that MEGA has no pending transfers:

```bash
mega-transfers
mega-sync-issues
```

Resolve or wait for pending changes before continuing.

## 2. Create and verify a safety snapshot

Create a uniquely dated directory under
`/home/tsp/.local/state/megacmd-migration/`. For example:

```bash
mkdir -p /home/tsp/.local/state/megacmd-migration/org-fuse-snapshot-YYYYMMDD
cp -a /home/tsp/org/. /home/tsp/.local/state/megacmd-migration/org-fuse-snapshot-YYYYMMDD/
```

Verify that the relative file lists match:

```bash
find /home/tsp/org -type f -printf '%P\n' | sort > /tmp/org-mounted-files.txt
find /home/tsp/.local/state/megacmd-migration/org-fuse-snapshot-YYYYMMDD \
  -type f -printf '%P\n' | sort > /tmp/org-snapshot-files.txt
diff -u /tmp/org-mounted-files.txt /tmp/org-snapshot-files.txt
```

Also compare checksums. Both commands must produce the same manifest:

```bash
(cd /home/tsp/org && find . -type f -print0 | sort -z | xargs -0 sha256sum) \
  > /tmp/org-mounted-sha256.txt
(cd /home/tsp/.local/state/megacmd-migration/org-fuse-snapshot-YYYYMMDD && \
  find . -type f -print0 | sort -z | xargs -0 sha256sum) \
  > /tmp/org-snapshot-sha256.txt
diff -u /tmp/org-mounted-sha256.txt /tmp/org-snapshot-sha256.txt
```

Do not proceed if either comparison reports a difference.

## 3. Remove the FUSE mount

Disable the mount first, then confirm that `/home/tsp/org` is no longer on
FUSE:

```bash
mega-fuse-disable org
findmnt -T /home/tsp/org -o TARGET,SOURCE,FSTYPE,OPTIONS
ls -la /home/tsp/org
```

The filesystem should now be the local home filesystem, normally Btrfs. The
underlying directory should be empty. If it contains files, stop and inspect
them instead of overwriting them.

Once verified, remove only the saved FUSE configuration:

```bash
mega-fuse-remove org
mega-fuse-show
```

`mega-fuse-remove` removes the mount configuration; it must not remove the
remote `/org` cloud folder.

## 4. Restore the local directory and enable two-way sync

Restore the verified snapshot into the now-local directory:

```bash
cp -a /home/tsp/.local/state/megacmd-migration/org-fuse-snapshot-YYYYMMDD/. \
  /home/tsp/org/
```

Configure normal two-way synchronization:

```bash
mega-sync /home/tsp/org /org
```

MEGAcmd reconciles the local and remote copies. Because the snapshot came from
the mounted remote folder and other editing was paused, they should agree.

## 5. Install the repo-owned user service

The repository should contain this unit at
`shared/config/systemd/user/megacmd.service`:

```ini
[Unit]
Description=MEGAcmd server and background synchronizations
Documentation=https://github.com/meganz/MEGAcmd
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/mega-cmd-server --do-not-log-to-stdout
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

Symlink it into the user systemd directory and restart it:

```bash
mkdir -p /home/tsp/.config/systemd/user
ln -sfnT \
  /home/tsp/.dotfiles/shared/config/systemd/user/megacmd.service \
  /home/tsp/.config/systemd/user/megacmd.service
systemctl --user daemon-reload
systemctl --user enable --now megacmd.service
systemctl --user restart megacmd.service
```

Restarting the server verifies that the MEGA sync configuration is persistent.

## 6. Verify the final state

```bash
systemctl --user is-enabled megacmd.service
systemctl --user is-active megacmd.service
readlink -f /home/tsp/.config/systemd/user/megacmd.service
mega-fuse-show
mega-sync --output-cols=LOCALPATH,REMOTEPATH,RUN_STATE,STATUS,ERROR
mega-sync-issues
findmnt -T /home/tsp/org -o TARGET,SOURCE,FSTYPE,OPTIONS
```

Expected results:

- The service is `enabled` and `active`.
- The service link resolves into `/home/tsp/.dotfiles`.
- There is no `org` FUSE mount.
- `/home/tsp/org` is on the local Btrfs filesystem.
- The sync pair is `/home/tsp/org` to `/org`.
- Its run state is `Running`, status is `Synced`, and error is `NO`.
- `mega-sync-issues` reports no issues.

Test local write latency with a disposable file:

```bash
TIMEFORMAT='local write elapsed: %R s'
time {
  printf local-save-check > /home/tsp/org/.emacs-local-save-check
  sync /home/tsp/org/.emacs-local-save-check
}
rm /home/tsp/org/.emacs-local-save-check
```

Check `mega-sync` again after MEGA observes the creation and deletion. It should
return to `Synced`.

## Rollback

If normal sync cannot be made healthy, pause or delete only that sync
configuration and retain all local data:

```bash
mega-sync --pause /home/tsp/org
```

The verified snapshot under
`/home/tsp/.local/state/megacmd-migration/` is the recovery source. Before
recreating a FUSE mount, move the local `/home/tsp/org` directory to a distinct,
explicit backup path so an empty mount point can be created. Do not recursively
delete either copy during rollback.
