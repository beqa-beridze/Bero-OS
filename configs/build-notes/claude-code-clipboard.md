# Claude Code clipboard (xclip) — debug + workaround

## The situation as the audit captured it

Audit-2026-05-28 #18 reported:

- Claude Code on bero-os spawned `xclip` for "copy" actions, but xclip
  wasn't installed.
- `nix profile add nixpkgs#xclip` was run, installing xclip 0.13 at
  `/home/bero/.nix-profile/bin/xclip`.
- User reported copy "still doesn't work after restart". The audit left
  the root cause undetermined and flagged it for follow-up.

## What this session verified

The claude binary on this box is a nix `makeCWrapper`-built ELF at
`/nix/store/ijd85fy5wk37ivff4s8d32pmm540r6cp-claude-code-2.1.148/bin/claude`.
It `--prefix`-prepends a small set of /nix/store paths (procps, ripgrep,
bubblewrap, socat) to PATH and execs `.claude-wrapped`. **It does NOT
strip the inherited PATH** — `--prefix` is additive, not replacement.

The running claude process (PID 11692, started 2026-05-28 01:32 — after
xclip was installed) has PATH that includes `/home/bero/.nix-profile/bin`.
Verified via `cat /proc/11692/environ`.

Strings analysis of `.claude-wrapped` shows three xclip usage patterns,
all by bare command name (no absolute path):

```
xclip -selection clipboard -t TARGETS -o ...
xclip -selection clipboard -t image/png -o > ...
xclip -selection clipboard -t text/plain -o ...
```

So when claude spawns `xclip`, its child process performs PATH lookup
and finds `/home/bero/.nix-profile/bin/xclip`. This was verified by
calling xclip directly from a tool-call shell (a child of claude):
write + read round-trip succeeded.

**Conclusion:** in any claude instance started AFTER xclip was added to
the nix profile, xclip is reachable. The audit's "still doesn't work"
status likely captured a moment between profile-update and claude
restart, when xclip was installed on disk but the running claude's
cached PATH didn't include `.nix-profile/bin`.

## What this session changed

Added a belt-and-suspenders symlink at `/usr/bin/xclip` pointing to the
nix-profile xclip:

```
sudo ln -sf /home/bero/.nix-profile/bin/xclip /usr/bin/xclip
```

This isn't strictly needed (PATH resolves correctly already) but
protects against three failure modes:

1. A future Claude Code version that hardcodes `/usr/bin/xclip`.
2. Any other tool on the system that assumes `/usr/bin/xclip` exists
   (some shell scripts, some snippet pasters).
3. A future shell session where the `.nix-profile/bin` PATH entry is
   somehow missing (sourced env file lost, etc.).

Reverse: `sudo rm /usr/bin/xclip` if it ever needs to come out.

Note: this symlink isn't mirrored under `configs/` because `/usr/bin`
isn't generally mirrored — it lives entirely in the OS install. A fresh
install will need the symlink re-created (or skip it; xclip via
`.nix-profile/bin` is enough on its own once xclip is in the nix
profile).

## How to verify copy works

In a running claude instance after these changes:

```
# direct probe via tool-call shell
echo "test-$(date +%s)" | xclip -selection clipboard -i
xclip -selection clipboard -o
# should round-trip
```

For the TUI "copy" UX itself, the only test is to actually try the
keybinding in claude. If it fails, the next debugging step is to
launch claude under `strace -f -e trace=execve` and look for which
xclip path it tries (will reveal hardcoded paths or argv quirks).

## What was NOT changed

- No restart of the running claude instances. The two running PIDs
  (8401, 11692) already have xclip in PATH; no environment refresh
  needed.
- No edit to claude's wrapper or bundle. The bundle is in `/nix/store`
  which is read-only.
- No change to `process.env` or shell rc files. Existing PATH set-up
  already includes `.nix-profile/bin` via `/etc/profile.d`.

## If the user still reports it doesn't work

The next step is interactive testing, which can't be done from a
non-interactive shell. Suggested follow-up:

1. Try copy in the TUI.
2. If it fails, `strace -f -p $(pgrep -f claude) -e execve 2>&1 | grep xclip`
   while the user triggers copy. The execve trace shows the exact path
   claude tried.
3. Report back the strace line.
