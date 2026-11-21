#!/bin/bash
# Runs cpvoice24.sh against a fake unit tree (CPV_ROOT) with a random 694088-byte stand-in
# for libairplay.so that carries the real stock bytes at the patch offsets.
# Needs: mksh (QNX-like ksh), xxd, sha1sum.  Usage: tests/sandbox_test.sh
set -u
H=$(cd "$(dirname "$0")/.." && pwd); W=$(mktemp -d); T=$W/root; P=0; F=0
trap 'rm -rf "$W"' EXIT
ok(){ echo "  PASS $*"; P=$((P+1)); }; bad(){ echo "  FAIL $*"; F=$((F+1)); }
chk(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
s1(){ sha1sum "$1" | cut -d' ' -f1; }
put(){ printf "$2" | dd of="$1" bs=1 seek=$(($3)) conv=notrunc 2>/dev/null; }
mk() {
 rm -rf $T; mkdir -p $T/net/mmx/fs/sda0/apps/sbin $T/net/mmx/mnt/app/eso/lib $T/net/mmx/mnt/app/eso/hmi/engdefs $T/net/mmx/mnt/persist $T/net/rcc/dev/shmem
 head -c 694088 /dev/urandom > $W/orig.so; put $W/orig.so '\x10\x40' 0x43238; put $W/orig.so '\xe1' 0x43247
 cp $W/orig.so $W/p24.so; put $W/p24.so '\x40' 0x43238; put $W/p24.so '\x11' 0x43247
 cp $W/orig.so $W/p48.so; put $W/p48.so '\x01\x49' 0x43238; put $W/p48.so '\x11' 0x43247
 cp -r $H/sd/CPVOICE24 $T/net/mmx/fs/sda0/
 sed -i "s/^ORIG_SHA1=.*/ORIG_SHA1=\"$(s1 $W/orig.so)\"/; s/^P24_SHA1=.*/P24_SHA1=\"$(s1 $W/p24.so)\"/; s/^P48_SHA1=.*/P48_SHA1=\"$(s1 $W/p48.so)\"/" $T/net/mmx/fs/sda0/CPVOICE24/cpvoice24.sh
 cp $(command -v sha1sum) $(command -v xxd) $T/net/mmx/fs/sda0/apps/sbin/
 cp $W/orig.so $T/net/mmx/mnt/app/eso/lib/libairplay.so
}
R(){ CPV_ROOT=$T mksh "$@" 2>&1 | sed 's/^/     | /'; }
SD=$T/net/mmx/fs/sda0/CPVOICE24/cpvoice24.sh; U=$T/net/mmx/mnt/app/eso/cpvoice24/cpvoice24.sh; LIB=$T/net/mmx/mnt/app/eso/lib/libairplay.so
same(){ cmp -s "$1" "$2"; }

echo "== setup"; mk; R $SD setup
chk "package + tools on unit" "[ -f $U ] && [ -x \$(dirname $U)/xxd ] && [ -x \$(dirname $U)/sha1sum ]"
chk "GEM screen linked" "[ -e $T/net/mmx/mnt/app/eso/hmi/engdefs/z_cpvoice24.esd ]"
chk "no Audi binary in package" "! ls \$(dirname $U) | grep -q libairplay"
chk "setup left libairplay.so alone" "same $LIB $W/orig.so"
echo "== install 24"; R $U install 24
chk "24 kHz bytes" "same $LIB $W/p24.so"; chk "backup is stock" "same $LIB.orig_k3663 $W/orig.so"; chk "no temp file" "[ ! -e $LIB.cpvoice24_new ]"
echo "== install 24 again"; R $U install 24; chk "unchanged" "same $LIB $W/p24.so"
echo "== switch to 48"; R $U install 48; chk "48 kHz bytes" "same $LIB $W/p48.so"; chk "3 bytes differ from stock" "[ \$(cmp -l $LIB $W/orig.so | wc -l) -eq 3 ]"
echo "== status"; R $U status
echo "== back to 24"; R $U install 24; chk "24 again" "same $LIB $W/p24.so"
echo "== uninstall"; R $U uninstall; chk "stock" "same $LIB $W/orig.so"
echo "== uninstall again"; R $U uninstall; chk "still stock" "same $LIB $W/orig.so"
echo "== uninstall without backup (rebuilt from the bytes)"; R $U install 48; rm $LIB.orig_k3663; R $U uninstall; chk "stock" "same $LIB $W/orig.so"
echo "== bad rate"; R $U install 99; chk "untouched" "same $LIB $W/orig.so"
echo "== unknown libairplay.so"; mk; R $SD setup; head -c 694088 /dev/urandom > $LIB; cp $LIB $W/unk; R $U install 48; chk "untouched" "same $LIB $W/unk"; chk "no backup of it" "[ ! -e $LIB.orig_k3663 ]"; R $U uninstall; chk "uninstall refuses too" "same $LIB $W/unk"
echo "== M.I.B. busy"; mk; R $SD setup; touch $T/net/rcc/dev/shmem/flash.mib; R $U install 48; chk "untouched" "same $LIB $W/orig.so"
echo "== no xxd anywhere"; mk; rm $T/net/mmx/fs/sda0/apps/sbin/xxd; R $SD setup; chk "lib untouched" "same $LIB $W/orig.so"
echo "== v1.x unit (patched48 + old package files) upgraded with setup"; mk; R $SD setup; cp $W/p48.so $LIB; cp $W/orig.so $LIB.orig_k3663; touch $T/net/mmx/mnt/app/eso/cpvoice24/libairplay.so.patched48; R $SD setup
chk "old binaries removed from package" "! ls $T/net/mmx/mnt/app/eso/cpvoice24 | grep -q libairplay"; R $U uninstall; chk "stock" "same $LIB $W/orig.so"
echo "== gem-off"; R $U gem-off; chk "link gone" "[ ! -e $T/net/mmx/mnt/app/eso/hmi/engdefs/z_cpvoice24.esd ]"
echo; echo "TOTAL $P passed, $F failed"; [ $F -eq 0 ]
