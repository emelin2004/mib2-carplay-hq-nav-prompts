CPVOICE24 2.0 - high-quality Apple CarPlay navigation prompts
Only for Audi MHI2 firmware MHI2_ER_AU57x_K3663_1 (MU1425), e.g. A6/A7 C7.5.
Full README and analysis: see the GitHub repository this came from.

SD card (the M.I.B. card, in SD1):
  /CPVOICE24/        this folder
  /mod/command.sh    = mod/command.sh.cpvoice24 for the one-time setup
  /apps/sbin/        sha1sum and xxd, already part of M.I.B.

1. GEM > M.I.B. > Advanced Settings > Individual Script   (setup: copies this package to the unit, adds a GEM screen)
2. Reboot
3. GEM > CPVOICE24 > Install 48 kHz (or 24 kHz) nav prompts
4. Reboot, test a CarPlay route
Uninstall: GEM > CPVOICE24 > Uninstall, reboot. Uninstall before any firmware update.
SSH rollback: mount -uw /mnt/app; cp /mnt/app/eso/lib/libairplay.so.orig_k3663 /mnt/app/eso/lib/libairplay.so; sync; reboot
