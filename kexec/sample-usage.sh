#!/bin/sh

/boot/kexec-1.8-2.5.74 --force --debug --command-line="auto BOOT_IMAGE=linux-2.5.74 ro root=305 console=ttyS1,9600n8" /boot/linux-2.5.74

