# CPVOICE24 – high-quality CarPlay navigation prompts for Audi MHI2 (K3663)

On Audi MIB2 High (Harman MHI2) units, Apple CarPlay navigation prompts sound muffled and "phone-like" while music sounds fine. The reason is that the head unit offers the iPhone **only PCM 16 kHz mono** for CarPlay's navigation-prompt stream. This package patches the unit so it offers **48 kHz mono** (or 24 kHz mono) instead. Music, Siri and phone calls are not changed.

It installs and uninstalls from the green menu (GEM) with [M.I.B.](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash), and it patches the unit's own `libairplay.so` in place. **No Audi, Harman or Apple binary is in this repository.**

| | Stock | 24 kHz | 48 kHz |
|---|---|---|---|
| Format offered for nav prompts (stream 101) | PCM 16 kHz mono (`0x10`) | PCM 24 kHz mono (`0x40`) | PCM 48 kHz mono (`0x4000`) |
| Bytes changed in `libairplay.so` | – | 2 | 3 |
| Car-tested | – | ✅ A6 C7.5 Avant, iPhone | ✅ A6 C7.5 Avant, iPhone (sounds close to music) |

## Supported firmware

**Only `MHI2_ER_AU57x_K3663_1` (MU1425)**, for example the Audi A6/A7 C7.5. The installer works only on the exact stock `libairplay.so` of that firmware (SHA1 `fa413305f4aebfe94c80cf454647d2042a507a45`, 694088 bytes). On any other file it stops and changes nothing.

Tested in one car so far. Reports from other K3663 cars, other phones and other amplifiers are welcome; please open an issue.

## Requirements

- M.I.B. (V3.6.0 tested) on its SD card in slot SD1. Its `apps/sbin/sha1sum` and `apps/sbin/xxd` are used.
- External power while installing: a charger, or the engine running.

## Install

1. Copy `sd/CPVOICE24/` to the root of the M.I.B. SD card. Copy `sd/mod/command.sh.cpvoice24` to `mod/command.sh` on the card. If the card already has a `mod/command.sh`, for example from MIB2-Patcher, rename it first and put it back afterwards.
2. In GEM: **M.I.B. → Advanced Settings → Individual Script → Run**. This copies the package to `/mnt/app/eso/cpvoice24` and adds a **CPVOICE24** GEM screen. `libairplay.so` is not touched in this step.
3. Reboot the MMI.
4. In GEM: **CPVOICE24 → Install 48 kHz nav prompts** (or 24 kHz).
5. Reboot, connect CarPlay and start a route.

GEM → CPVOICE24 → **Status** shows the current state. To see the format the iPhone actually picked, run this over SSH after a prompt: `sloginfo | grep -i "Audio Format"`.

## Uninstall / switch

- **Uninstall:** GEM → CPVOICE24 → **Uninstall**, then reboot. It writes the stock bytes back and checks the SHA1.
- You can switch between 24 kHz and 48 kHz directly.
- **Uninstall before any firmware update.**
- Manual rollback over SSH: `mount -uw /mnt/app; cp /mnt/app/eso/lib/libairplay.so.orig_k3663 /mnt/app/eso/lib/libairplay.so; sync; reboot`

## Safety

- Every step is checked by SHA1: the current file, the backup, and the new file before it replaces the old one.
- The stock file is kept as `libairplay.so.orig_k3663`.
- The new file is written under a temporary name and moved into place only after its check passes.
- `libairplay.so` is loaded only by the CarPlay process (`dio_manager`), after the MMI has started. Booting, the HMI, GEM and SSH do not use it. If something went wrong, the worst case is CarPlay audio or CarPlay itself failing, and GEM stays usable for Uninstall.
- The installer refuses to run while an M.I.B. flash, backup or reboot is in progress.

## Compatibility with other mods

- [mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map): its installer checks the size of `libairplay.so` (694088), which stays the same. Its hooks attach to CarPlay session functions, not to the patched function.
- [MIB2-Patcher](https://github.com/tfourj/MIB2-Patcher) (JOKERBTN and others): it doesn't touch `libairplay.so`.

## How it works

See [docs/ANALYSIS.md](docs/ANALYSIS.md).

## Credits

- The idea and the MHI2Q findings come from **Matze89x** in [luka-dev/mib2q-carplay-rgi#75](https://github.com/luka-dev/mib2q-carplay-rgi/issues/75). On MHI2Q, prompts also needed re-routing to a 24 kHz device. On K3663 the nvaudio path takes the negotiated rate directly.
- The GEM and installer patterns follow M.I.B. and MIB2-Patcher.

## Disclaimer

Use at your own risk. This is not affiliated with Audi, Harman or Apple.
