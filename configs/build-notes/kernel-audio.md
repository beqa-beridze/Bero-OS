# Kernel audio (HDA codec) build notes

## Lesson learned (kernel rebuild #2, 2026-05-22)

Two rebuilds went into getting audio working on the X230. The first one was
based on a wrong diagnosis. The second was the real fix. Writing this up so
we don't waste another evening if a future kernel touches this area.

## Symptom

Card detected at the PCI level, codec_mask non-zero (the HDA controller
sees codecs on the bus during link reset), but no sound card appears and
`aplay -l` reports nothing.

Vanilla cmdline gave two dmesg lines and died in 12ms:

```
snd_hda_intel 0000:00:1b.0: bound 0000:00:02.0 (ops intel_audio_component_bind_ops)
snd_hda_intel 0000:00:1b.0: Cannot probe codecs, giving up
```

Adding `snd_hda_intel.single_cmd=1` produced a different-looking failure:

```
snd_hda_intel 0000:00:1b.0: spurious response 0x10ec0269:0x0, last cmd=0x0f0000
snd_hda_intel 0000:00:1b.0: spurious response 0x17aa21fa:0x0, last cmd=0x1f2000
... more spurious responses with valid codec data ...
snd_hda_intel 0000:00:1b.0: Cannot probe codecs, giving up
```

The "spurious response" data was actually the correct codec answers — Realtek
vendor ID `0x10ec0269`, Lenovo X230 subsystem ID `0x17aa21fa`. That misled
rebuild #1's diagnosis into thinking the codec was "alive but talking out of
step" and the codec module was missing.

It wasn't missing. The codec drivers had been built. They were just never
loaded.

## Root cause: y/m mismatch in the HDA build

Our `.config` had:

```
CONFIG_SND_HDA=y                       # snd-hda-codec built-in
CONFIG_SND_HDA_INTEL=y                 # snd_hda_intel built-in
CONFIG_SND_HDA_CODEC_REALTEK=m         # codec driver = MODULE
CONFIG_SND_HDA_CODEC_REALTEK_LIB=m     # codec lib = MODULE
CONFIG_SND_HDA_CODEC_CONEXANT=m        # MODULE
CONFIG_SND_HDA_GENERIC=m               # generic fallback = MODULE
CONFIG_SND_HDA_CODEC_ALC*=m            # individual ALC drivers = MODULE
```

This combination looks fine on paper but is silently broken. Look at
`sound/hda/common/bind.c` in the kernel source:

```c
static void request_codec_module(struct hda_codec *codec)
{
#ifdef MODULE
    char modalias[32];
    ...
    if (mod)
        request_module(mod);
#endif /* MODULE */
}
```

The **entire body** of `request_codec_module` is wrapped in `#ifdef MODULE`.
That `#ifdef` is set per object file at compile time, based on whether the
object is being built as a module. `bind.c` lives in `snd-hda-codec.ko`,
which is gated by `CONFIG_SND_HDA`.

When `CONFIG_SND_HDA=y` (our case), `snd-hda-codec` is **built into vmlinuz**,
so `#ifdef MODULE` is false and `request_codec_module` is an empty stub. It
never calls `request_module`. The codec `.ko` files sit on disk forever,
unloaded.

`snd_hda_codec_configure` then runs through `codec_bind_module` (no-op) →
`codec_bind_generic` (also gated by `#ifdef MODULE`, also no-op) → no driver
binds → returns -ENODEV → `azx_codec_configure` returns -ENODEV →
"Cannot probe codecs, giving up".

That 12ms timing was the giveaway. No probing actually happened. No timeouts.
Just immediate -ENODEV because no codec driver was ever asked for.

The `single_cmd=1` red herring: the "spurious response" log lines fire from
`snd_hdac_bus_update_rirb` (DMA mode) when a response arrives for an address
with `rirb.cmds[addr] == 0`. With `single_cmd=1`, the driver stops
incrementing `rirb.cmds[addr]` when sending commands — but the controller's
RIRB DMA stays active in hardware (the codec doesn't know about driver-side
mode switches). So responses keep landing in the RIRB ring and now they
*look* unexpected, which surfaces them in dmesg. The codec was always
replying; we just started seeing the replies once single_cmd shifted the
bookkeeping.

## Fix

Flip every codec driver and the generic fallback to `=y` in `.config`,
`make olddefconfig`, rebuild:

```
CONFIG_SND_HDA_CODEC_REALTEK=y
CONFIG_SND_HDA_CODEC_REALTEK_LIB=y
CONFIG_SND_HDA_CODEC_CONEXANT=y
CONFIG_SND_HDA_GENERIC=y
# olddefconfig auto-promotes:
CONFIG_SND_HDA_CODEC_ALC260=y ... ALC882=y
```

With the codec drivers linked into the kernel, they auto-register via the
hda bus device model the moment their codec device is created — no
`request_module` needed. First boot after the rebuild:

```
snd_hda_codec_alc269 hdaudioC0D0: ALC269VC: picked fixup for PCI SSID 17aa:21fa
snd_hda_codec_alc269 hdaudioC0D0: autoconfig for ALC269VC: ...
input: HDA Intel PCH Headphone as ...
input: HDA Intel PCH Mic as ...
```

`aplay -l` shows `card 0: PCH [HDA Intel PCH], device 0: ALC269VC Analog`.

Also dropped `snd_hda_intel.single_cmd=1` from the grub menuentry. It was
chasing a phantom and added noise.

## Rule for future kernel changes

**HDA core and HDA codec drivers must share a build target.** Pick one:

- `CONFIG_SND_HDA=y` and **all** `CONFIG_SND_HDA_CODEC_*=y` (everything in
  vmlinuz, what we have now)
- `CONFIG_SND_HDA=m` and `CONFIG_SND_HDA_CODEC_*=m` (everything as modules,
  what most distros do)

Don't mix. The `#ifdef MODULE` in `bind.c` means built-in HDA core will
silently refuse to load modular codecs. Kconfig does **not** warn about this
mismatch — `make olddefconfig` accepts it without complaint.

If you ever flip `CONFIG_SND_HDA` between `y` and `m`, audit every
`CONFIG_SND_HDA_CODEC_*` to match.

## Auto-Mute Mode gotcha (separate issue, also bit us)

Even after the rebuild fixed codec init and a card appeared, the speaker
stayed silent. ALC269 ships with an "Auto-Mute Mode" mixer control that
mutes the speaker when the codec thinks a headphone is plugged in. On this
X230 it was muting the speaker without any headphone connected — probably a
jack-detect quirk on this unit.

Fix:

```
amixer -c 0 sset 'Auto-Mute Mode' Disabled
alsactl store
```

Persists via `alsa-restore.service`, which is pulled in by the
`90-alsa-restore.rules` udev rule when `/dev/snd/controlC*` shows up. On
clean shutdown the service's `ExecStop=-/usr/sbin/alsactl store` saves any
in-session changes back to `/var/lib/alsa/asound.state`.

If audio ever goes silent again after a reboot, first thing to check:

```
amixer -c 0 sget 'Auto-Mute Mode'
amixer -c 0 sget Master
amixer -c 0 sget Speaker
```

## Reference

- Rebuild #1 (uncommitted, sat in the tree as the "audio codecs + USER_NS"
  attempt at commit `1ea3ab6`): correct on `USER_NS=y` and on the principle
  of "we need codec drivers built", wrong on building them as modules. The
  `single_cmd=1` cmdline workaround that came out of debugging that build
  was based on the spurious-response misreading and should never have been
  added.
- Rebuild #2 (this one): only changed the y/m setting on the codecs, kept
  USER_NS=y. New vmlinuz 14.63 MB vs 14.52 MB from #1.
- Source paths referenced:
  - `sound/hda/common/bind.c:211` — `request_codec_module` definition
  - `sound/hda/common/bind.c:240` — `codec_bind_module`
  - `sound/hda/common/bind.c:280` — `codec_bind_generic`
  - `sound/hda/common/controller.c:285,298` — the two "spurious response"
    log sites (both in the RIRB DMA path, not the PIO path)
  - `sound/hda/controllers/intel.c:2375` — "Cannot probe codecs, giving up"
