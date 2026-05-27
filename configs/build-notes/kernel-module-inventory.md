# Kernel module inventory (6.18.10-bero-os)

The 2026-05-22 kernel build (`/boot/vmlinuz-6.18.10-bero-os`) ships 11
out-of-vmlinuz modules under `/lib/modules/6.18.10/kernel/`. This note
catalogs them, clarifies which are loaded, and explains how to restore
them on rebuild.

## Important framing — the audit was partly wrong

Audit-2026-05-28 #9 read `/proc/sys/kernel/tainted == 4` as "bit 2 =
OOT_MODULE" and inferred the system had out-of-tree modules loaded.
That is incorrect on two counts:

1. **Bit 2 is not `TAINT_OOT_MODULE`.** Per the kernel docs
   (`Documentation/admin-guide/tainted-kernels.rst`), bit 2 is
   `TAINT_UNSAFE_SMP` (also rendered as `TAINT_CPU_OUT_OF_SPEC` in
   recent kernels) — set when the kernel detects the running CPU is
   missing microcode fixes for known issues. `TAINT_OOT_MODULE` is
   actually bit 12 (value `4096`).
2. **The `find -newer vmlinuz` filter from the audit catches every
   module, not just OOT ones.** Kernel builds compile `vmlinuz` first
   and modules second, so every `.ko` mtime is later than the kernel
   image mtime. The filter is non-selective; it returns the full
   inventory.

Verified live: `modinfo` on each of the 11 modules shows `intree=Y` and
`vermagic=6.18.10`. Zero out-of-tree modules are loaded or installed.

The bit-2 taint very likely comes from old Intel microcode (rev `0x16`
on this i5-3320M, see `audit #3 — deferred`) — `/proc/cpuinfo`'s `bugs`
line lists `old_microcode` explicitly.

## The 11 modules

| Module | Path | Kconfig | Loaded? |
|---|---|---|---|
| `iwlwifi.ko` | `drivers/net/wireless/intel/iwlwifi/` | `CONFIG_IWLWIFI=m` | yes (used by NM) |
| `iwldvm.ko` | `drivers/net/wireless/intel/iwlwifi/dvm/` | `CONFIG_IWLDVM=m` | yes (autoloaded by iwlwifi) |
| `x86_pkg_temp_thermal.ko` | `drivers/thermal/intel/` | `CONFIG_X86_PKG_TEMP_THERMAL=m` | yes |
| `xt_LOG.ko` | `net/netfilter/` | `CONFIG_NETFILTER_XT_TARGET_LOG=m` | no |
| `xt_MASQUERADE.ko` | `net/netfilter/` | `CONFIG_NETFILTER_XT_TARGET_MASQUERADE=m` | no |
| `xt_addrtype.ko` | `net/netfilter/` | `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=m` | no |
| `xt_mark.ko` | `net/netfilter/` | `CONFIG_NETFILTER_XT_MARK=m` | no |
| `nf_log_syslog.ko` | `net/netfilter/` | `CONFIG_NF_LOG_SYSLOG=m` | no |
| `nf_reject_ipv4.ko` | `net/ipv4/netfilter/` | `CONFIG_NF_REJECT_IPV4=m` | no |
| `nf_reject_ipv6.ko` | `net/ipv6/netfilter/` | `CONFIG_NF_REJECT_IPV6=m` | no |
| `efivarfs.ko` | `fs/efivarfs/` | `CONFIG_EFIVAR_FS=m` | no |

Three are loaded right now (per `/proc/modules`): `iwlwifi`, `iwldvm`,
`x86_pkg_temp_thermal`. The eight netfilter / efivarfs modules sit on
disk waiting to be loaded by demand (iptables/nftables rules, or
direct `modprobe`). None of them are pulled in by anything in batch 7.

Why are netfilter `=m` if iptables isn't installed and there's no
firewall today? Because the kernel maintainer chose to keep them as
modules for future flexibility — adding `nftables` later is one
`modprobe` away with the disk-side .ko already present.

## Restoring on a rebuild

These modules are 100% upstream. To preserve them across a kernel
rebuild from a clean `/sources/linux-6.18.10/` tree:

1. Start with the current config:
   ```
   cp /boot/config-6.18.10 /sources/linux-6.18.10/.config
   cd /sources/linux-6.18.10
   make olddefconfig
   ```
2. Verify the symbols above all still show `=m` after olddefconfig:
   ```
   for s in IWLWIFI IWLDVM X86_PKG_TEMP_THERMAL NETFILTER_XT_TARGET_LOG \
            NETFILTER_XT_TARGET_MASQUERADE NETFILTER_XT_MATCH_ADDRTYPE \
            NETFILTER_XT_MARK NF_LOG_SYSLOG NF_REJECT_IPV4 NF_REJECT_IPV6 \
            EFIVAR_FS; do
     grep "^CONFIG_$s=" .config
   done
   ```
3. Build kernel + modules:
   ```
   make -j$(nproc)
   sudo make modules_install
   sudo make install
   ```

No out-of-tree source tarball needs to be fetched — every module is
in-tree.

## What this does NOT do

- Does not clear the bit-2 taint. That requires fresh Intel microcode
  (`intel-microcode` package, or `CONFIG_EXTRA_FIRMWARE`-embedded
  blob). See audit #3 — deferred.
- Does not enable a firewall. The netfilter modules are available but
  unloaded. Adding `iptables-nft` or `nftables` userland is a separate
  task.
