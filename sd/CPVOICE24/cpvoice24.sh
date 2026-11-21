#!/bin/sh
# CPVOICE24 2.0 - high-quality Apple CarPlay navigation prompts on Audi MHI2 K3663
#
# Stock MHI2_ER_AU57x_K3663_1 (MU1425) offers the iPhone only PCM 16 kHz mono for
# the CarPlay "alternate" audio stream (type 101 = navigation prompts). This patches
# AudioSessionGetSupportedOutputFormats in the unit's OWN /mnt/app/eso/lib/libairplay.so
# so that stream offers PCM 24 kHz mono (0x40) or 48 kHz mono (0x4000) instead.
# Music, Siri and calls are unchanged. No Audi/Harman/Apple binary is shipped:
# the unit's file is copied, 2-3 bytes are written with xxd, and every result is
# checked by SHA1 before it replaces anything.
#
#   cpvoice24.sh setup           copy this package from the SD card to the unit + add the GEM screen
#   cpvoice24.sh install [24|48] patch libairplay.so (default 24), reboot afterwards
#   cpvoice24.sh uninstall       write the stock bytes back, reboot afterwards
#   cpvoice24.sh status          show what is installed
#   cpvoice24.sh gem-off         remove the GEM screen
VERSION="2.0"
export PATH=:/proc/boot:/sbin:/bin:/usr/bin:/usr/sbin:/net/mmx/bin:/net/mmx/usr/bin:/net/mmx/usr/sbin:/net/mmx/sbin:/net/mmx/mnt/app/armle/bin:/net/mmx/mnt/app/armle/sbin:/net/mmx/mnt/app/armle/usr/bin:/net/mmx/mnt/app/armle/usr/sbin:$PATH

ROOT="${CPV_ROOT:-}"                      # empty on the unit; the sandbox test sets it
SD_PKG="${VOLUME:+$ROOT$VOLUME/CPVOICE24}"; SD_PKG="${SD_PKG:-$ROOT/net/mmx/fs/sda0/CPVOICE24}"
SD_TOOLS="$SD_PKG/../apps/sbin"           # M.I.B.'s sha1sum and xxd
APP_MOUNT="$ROOT/net/mmx/mnt/app"
PKG="$APP_MOUNT/eso/cpvoice24"
LIB="$APP_MOUNT/eso/lib/libairplay.so"
BAK="$LIB.orig_k3663"
NEW="$LIB.cpvoice24_new"
ENGDEFS="$APP_MOUNT/eso/hmi/engdefs"
GEM_LINK="$ENGDEFS/z_cpvoice24.esd"
SHMEM="$ROOT/net/rcc/dev/shmem"
LOG="$ROOT/net/mmx/mnt/persist/cpvoice24.log"

# libairplay.so of MHI2_ER_AU57x_K3663_1 (694088 bytes)
SIZE=694088
ORIG_SHA1="fa413305f4aebfe94c80cf454647d2042a507a45"
P24_SHA1="e8f2a206d0027d9b958682bdce7c05b8ecdeb23a"
P48_SHA1="5e977f44f82f733b1ad37705671b4fd9428b6dc6"
# xxd -r patch lines: offset: bytes
#   0x43238  moveq r4,#0x10   10 40 a0 03  -> #0x40: 40 40 a0 03 | #0x4000: 01 49 a0 03
#   0x43244  orr r4,r4,r0     00 40 84 e1  -> orrne:   00 40 84 11  (byte 0x43247)
STOCK_BYTES="00043238: 1040
00043247: e1"
P24_BYTES="00043238: 4040
00043247: 11"
P48_BYTES="00043238: 0149
00043247: 11"

log() { echo "$*"; { echo "$*" >> "$LOG"; } 2> /dev/null; }
die() { log "ERROR: $*"; rm -f "$NEW" 2> /dev/null; mount_ro; exit 1; }
mount_rw() {
	[ -n "$ROOT" ] || mount -uw "$APP_MOUNT" 2> /dev/null
	t="$APP_MOUNT/eso/.cpvoice24_rw_test"
	( : > "$t" ) 2> /dev/null || die "$APP_MOUNT is not writable, nothing changed"
	rm -f "$t"
}
mount_ro() { [ -n "$ROOT" ] && return 0; sync; mount -ur "$APP_MOUNT" 2> /dev/null || echo "note: $APP_MOUNT stays writable until the reboot"; }

find_tool() { # $1 = name
	for t in "$PKG/$1" "$SD_TOOLS/$1" "$ROOT/net/mmx/fs/sda0/apps/sbin/$1" "$ROOT/net/rcc/usr/bin/$1"; do
		[ -x "$t" ] && { echo "$t"; return 0; }
	done
	command -v "$1" 2> /dev/null
}
sha1_of() {
	tool=$(find_tool sha1sum) || return 1
	[ -n "$tool" ] || return 1
	sum=$("$tool" "$1" 2> /dev/null) || return 1
	set -- $sum
	echo "$1"
}
have_tools() { [ -n "$(find_tool sha1sum)" ] && [ -n "$(find_tool xxd)" ]; }

state_of() { # stock | patched24 | patched48 | missing | unknown:<sha1>
	[ -f "$1" ] || { echo missing; return; }
	s=$(sha1_of "$1")
	case "$s" in
		"$ORIG_SHA1") echo stock ;;
		"$P24_SHA1") echo patched24 ;;
		"$P48_SHA1") echo patched48 ;;
		*) echo "unknown:$s" ;;
	esac
}

check_not_busy() {
	for lock in backup reboot flash; do
		[ -f "$SHMEM/$lock.mib" ] && die "M.I.B. $lock is running, try again when it has finished"
	done
	return 0
}

# Build $NEW from the current $LIB (already checked to be stock or a known patch):
# write the stock bytes, then $1 (patch lines, may be empty), and check $2 (sha1).
build_new() {
	bn_bytes="$1"; bn_want="$2"
	rm -f "$NEW" 2> /dev/null
	cp "$LIB" "$NEW" || return 1
	x=$(find_tool xxd)
	echo "$STOCK_BYTES" | "$x" -r - "$NEW" || return 1
	if [ -n "$bn_bytes" ]; then echo "$bn_bytes" | "$x" -r - "$NEW" || return 1; fi
	set -- $(wc -c < "$NEW")
	[ "$1" = "$SIZE" ] || { log "size check failed"; return 1; }
	[ "$(sha1_of "$NEW")" = "$bn_want" ] || { log "SHA1 check of the new file failed"; return 1; }
}
# Put $NEW in place by rename (the running CarPlay process keeps its copy until the reboot)
swap_new() { # $1 = expected sha1
	chmod 755 "$NEW" 2> /dev/null
	mv -f "$NEW" "$LIB" || return 1
	sync
	[ "$(sha1_of "$LIB")" = "$1" ]
}

do_setup() {
	log "== setup (CPVOICE24 $VERSION)"
	check_not_busy
	[ -f "$SD_PKG/cpvoice24.sh" ] || die "$SD_PKG not found on the SD card in SD1"
	mount_rw
	mkdir -p "$PKG/esd" || die "could not create $PKG"
	rm -f "$PKG"/libairplay.so.* "$PKG/esd/install.sh" 2> /dev/null   # files of older versions
	for f in cpvoice24.sh README.txt; do
		cp "$SD_PKG/$f" "$PKG/$f" || die "could not copy $f"
	done
	cp "$SD_PKG"/esd/* "$PKG/esd/" || die "could not copy the GEM screen"
	for t in sha1sum xxd; do
		[ -x "$SD_TOOLS/$t" ] && cp "$SD_TOOLS/$t" "$PKG/$t"
	done
	chmod 755 "$PKG"/*.sh "$PKG"/esd/*.sh "$PKG/sha1sum" "$PKG/xxd" 2> /dev/null
	have_tools || die "sha1sum or xxd not found (they come with M.I.B. in apps/sbin on the SD card)"
	rm -f "$GEM_LINK" 2> /dev/null
	ln -s "$PKG/esd/CPVOICE24.esd" "$GEM_LINK" 2> /dev/null || on -f mmx ln -s "$PKG/esd/CPVOICE24.esd" "$GEM_LINK" 2> /dev/null || cp "$PKG/esd/CPVOICE24.esd" "$GEM_LINK"
	mount_ro
	[ -e "$GEM_LINK" ] || die "could not add the GEM screen"
	log "done: the GEM screen CPVOICE24 shows up after the next reboot. libairplay.so was not changed."
}

do_install() {
	rate="${1:-24}"
	case "$rate" in
		24) BYTES="$P24_BYTES"; WANT="$P24_SHA1" ;;
		48) BYTES="$P48_BYTES"; WANT="$P48_SHA1" ;;
		*) die "unknown rate $rate (use 24 or 48)" ;;
	esac
	log "== install $rate kHz (CPVOICE24 $VERSION)"
	check_not_busy
	have_tools || die "sha1sum or xxd not found, run setup again with the M.I.B. SD card in SD1"
	st=$(state_of "$LIB")
	case "$st" in
		"patched$rate") log "$rate kHz is already installed, nothing to do"; return 0 ;;
		stock|patched24|patched48) ;;
		*) die "libairplay.so is not the stock K3663 file or one of these patches ($st). Nothing changed." ;;
	esac
	mount_rw
	if [ "$st" = stock ] && [ "$(state_of "$BAK")" != stock ]; then
		rm -f "$BAK" 2> /dev/null
		cp "$LIB" "$BAK" && [ "$(state_of "$BAK")" = stock ] || { rm -f "$BAK"; die "could not back up libairplay.so, nothing changed"; }
		log "stock libairplay.so backed up to $BAK"
	fi
	build_new "$BYTES" "$WANT" || die "could not build the patched file, nothing changed"
	swap_new "$WANT" || die "COULD NOT VERIFY libairplay.so AFTER THE SWAP - run Uninstall, or over SSH: cp $BAK $LIB"
	mount_ro
	log "done: $rate kHz installed and checked. Reboot the MMI now."
}

do_uninstall() {
	log "== uninstall"
	check_not_busy
	have_tools || die "sha1sum or xxd not found, run setup again with the M.I.B. SD card in SD1"
	st=$(state_of "$LIB")
	case "$st" in
		stock) log "stock libairplay.so is already in place, nothing to do"; return 0 ;;
		patched24|patched48) ;;
		*) die "libairplay.so is not one of these patches ($st), something else changed it. Nothing changed." ;;
	esac
	mount_rw
	build_new "" "$ORIG_SHA1" || die "could not rebuild the stock file, nothing changed"
	swap_new "$ORIG_SHA1" || die "COULD NOT VERIFY libairplay.so AFTER THE SWAP - over SSH: cp $BAK $LIB"
	mount_ro
	log "done: stock libairplay.so is back. Reboot the MMI now."
}

do_status() {
	echo "CPVOICE24 $VERSION - CarPlay nav prompts at 24/48 kHz (MHI2_ER_AU57x_K3663_1 only)"
	have_tools || { echo "sha1sum or xxd not found"; return 1; }
	case "$(state_of "$LIB")" in
		patched24) echo "libairplay.so: PATCHED (24 kHz nav prompts)" ;;
		patched48) echo "libairplay.so: PATCHED (48 kHz nav prompts)" ;;
		stock) echo "libairplay.so: stock (16 kHz nav prompts)" ;;
		*) echo "libairplay.so: $(state_of "$LIB") - not a file this package knows" ;;
	esac
	echo "stock backup $BAK: $(state_of "$BAK")"
	echo "Format the iPhone picked, over SSH: sloginfo | grep -i \"Audio Format\""
}

do_gem_off() {
	mount_rw; rm -f "$GEM_LINK" 2> /dev/null; mount_ro
	log "GEM screen removed (after the next reboot)"
}

case "$1" in
	setup) do_setup ;;
	install) do_install "$2" ;;
	uninstall) do_uninstall ;;
	status) do_status ;;
	gem-off) do_gem_off ;;
	*) echo "CPVOICE24 $VERSION - usage: $0 setup|install [24|48]|uninstall|status|gem-off"; exit 1 ;;
esac
