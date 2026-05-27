# sshd: ExecStartPre host-key guard

## What this fixes

If `/etc/ssh/ssh_host_*` is ever wiped (manual `rm`, fresh-install
restore from `configs/`, hostname/identity reset, partial /etc rebuild),
the previous `sshd.service` failed `ExecStartPre=/usr/sbin/sshd -t`
because `sshd -t` returns non-zero when no host keys exist. systemd
treats that as start-failure, the daemon never comes up, and SSH access
is gone until someone with local console runs `ssh-keygen -A` by hand.

## The added line

`/etc/systemd/system/sshd.service`:

```
[Service]
Type=simple
ExecStartPre=/bin/sh -c '[ -f /etc/ssh/ssh_host_ed25519_key ] || /usr/bin/ssh-keygen -A'
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D
```

Order matters: the keygen guard runs first, then `-t` validates the
config (which now sees a valid HostKey). systemd executes multiple
`ExecStartPre=` lines in order; both must exit 0 for `ExecStart=` to
run.

Mirror in `configs/etc/systemd/system/sshd.service` is kept in sync.

## Audit recommendation needed a correction

Audit-2026-05-28 #7 suggested `/usr/sbin/ssh-keygen`. The binary on
bero-os actually lives at `/usr/bin/ssh-keygen` (verified). Using the
audit's path produced `sh: line 1: /usr/sbin/ssh-keygen: No such file
or directory` and the service still failed on the fresh-keys path.
Corrected to `/usr/bin/ssh-keygen`.

If you ever switch SSH packages or relocate binaries, re-verify with
`command -v ssh-keygen` and update both files.

## Verification (live, performed 2026-05-28)

```
# baseline restart with existing keys
sudo systemctl restart sshd && systemctl is-active sshd
# -> active   (both ExecStartPre lines exited 0/SUCCESS)

# destructive simulation
sudo systemctl stop sshd
sudo mv /etc/ssh/ssh_host_* /tmp/keybackup/
sudo systemctl start sshd     # ExecStartPre keygen fires
sudo journalctl -u sshd -n 5
# -> "ssh-keygen: generating new host keys: RSA ECDSA ED25519"
ssh-keygen -lf /etc/ssh/ssh_host_*.pub
# -> 3 fresh fingerprints, all dated now()

# restore
sudo systemctl stop sshd
sudo rm /etc/ssh/ssh_host_*
sudo mv /tmp/keybackup/* /etc/ssh/
sudo systemctl start sshd
```

## What this does NOT do

- Does not rotate existing host keys. If you want to rotate, wipe them
  manually and restart sshd — the guard then generates fresh ones.
- Does not change SSH security posture (audit #1 is separate:
  `PermitRootLogin yes` + trivial passwords + no firewall — deferred).
- Does not handle the case where `/etc/ssh` doesn't exist as a
  directory. `ssh-keygen -A` would fail. Easy to fix if it ever
  matters by prefixing with `mkdir -p /etc/ssh`.

## Why ed25519 is the sentinel file

`ssh-keygen -A` writes all enabled key types (RSA, ECDSA, ED25519 by
default on modern OpenSSH). Checking only one — the ed25519 key, the
most modern type — is enough to know whether the box has been
keygen'd. If somebody manually deletes just the rsa key, this guard
won't re-create it (rare, hand-fix). For full re-key, wipe all.
