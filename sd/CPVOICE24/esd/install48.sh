#!/bin/sh
# GEM entry: CPVOICE24 install 48 kHz (runs on the RCC like the M.I.B. scripts)
on -f rcc /bin/sh /net/mmx/mnt/app/eso/cpvoice24/cpvoice24.sh install 48
# GEM closes the output when the script ends, so leave time to read it
sleep 10
