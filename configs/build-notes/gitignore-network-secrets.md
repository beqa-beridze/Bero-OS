# gitignore: NetworkManager/system-connections

## What this protects

Live `/etc/NetworkManager/system-connections/*.nmconnection` files store wifi
PSKs in cleartext (NM treats the file mode `0600` as the secret boundary).
Anyone with read access to one of those files can read the wifi password.

The Bero-OS workflow regularly mirrors `/etc` into `configs/etc/` so the repo
captures system state. Without an ignore rule, a wholesale snapshot
(`cp -r /etc configs/etc`, an rsync helper, a future `bero-snapshot` script)
would land the cleartext PSKs into a public GitHub repo.

## The line

`.gitignore`:

```
**/NetworkManager/system-connections/
```

- `**/` matches at any depth under the repo, so the rule catches the canonical
  `configs/etc/NetworkManager/system-connections/` and any future variant.
- Trailing slash forces a directory match. git stops descending entirely.
  No file inside can ever be tracked, regardless of name or extension.

## Alternative considered

The audit recommendation was `**/NetworkManager/system-connections/*` — a
file glob. Functionally equivalent for current `.nmconnection` files, but the
directory form is stricter: a stray `.gitkeep` or new file type (e.g.
`*.nmsecret` if NM ever adds one) is still ignored automatically.

## What this does NOT do

- Does not encrypt the live files at `/etc/NetworkManager/system-connections/`.
  Read access to that path still leaks the PSK. NM gates it via mode `0600`
  owned by root; the host-side OS protection is what it is.
- Does not retroactively scrub the repo. None of the PSK files were ever
  committed — confirmed via `git log -- '**/system-connections/**'` returning
  no history before this rule.
- Does not rotate the existing PSKs. That belongs to a separate security pass.

## How to verify the rule is live

```
git check-ignore -v configs/etc/NetworkManager/system-connections/anything.nmconnection
```

Should print the `.gitignore` line that matched.
