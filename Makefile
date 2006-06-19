# set to anything other than empty to see commands being executed
V =

FWVER     = 0.4
BASE_KVER = 2.6.15
KVER      = 2.6.16-rc4

CURDIR        := $(shell pwd)
FINAL_DIR     := $(CURDIR)/image
BUILD_DIR     := $(CURDIR)/build
SOURCE_DIR    := $(CURDIR)/sources

INITRAMFS     := $(FINAL_DIR)/initramfs_data.cpio
KDIR          := $(BUILD_DIR)/kernel/linux-$(KVER)

TEMP_FILES    := $(KDIR)/output $(KDIR)/prebuilt/initramfs_data.cpio
PERM_FILES    := $(INITRAMFS)

# Use the configuration suffixes to determine the list of platforms
PLATFORMS     := $(shell x=( $$(echo kernel/$(KVER)/configs/config-$(KVER)-$(FWVER)-*) ); echo $${x[@]\#\#*-})

# various commands which can be overridden by the command line.

cmd_sudo      := sudo
cmd_7za       := 7za
cmd_gzip      := gzip
cmd_cpio      := cpio
cmd_tar       := tar
cmd_install   := install
cmd_bzip2     := bzip2
cmd_find      := find
cmd_patch     := patch
cmd_kgcc      := gcc-3.4 # WARNING! gcc-4.0.[012] produces bad kexec code !
cmd_lzma      := lzma    # see doc/lzma-howto.txt for this
cmd_make      := $(MAKE)

########################################################################

ifeq ($(V),)
  Q = @
else
  Q =
endif

######## end of configuration, beginning of the standard targets #######

help:
	@echo "Usage: make < help | check | rootfs | kernel | clean | mrproper | distclean >"
	@echo "  Use 'check' to check your build environment."
	@echo "  Use 'mrproper' to clean the 'build' directory and temp files."
	@echo "  Use 'distclean' to clean everything including final files."
	@echo "  Use 'rootfs' FIRST to build only the initramfs."
	@echo "  Use 'kernel' to build the final firmware image for the following platforms :"
	@echo "      >> $(PLATFORMS) <<"
	@echo

check:
	@echo -n "Checking /dev/null existence : "
	@[ -c /dev/null ] && echo "OK" || echo "Failed"
	@echo -n "Checking source directory : "
	@[ -d "$(SOURCE_DIR)/." ] && echo "OK" || echo "Failed"

	@echo -n "Checking kernel source linux-$(BASE_KVER).tar.bz2 : "
	@[ -s "$(SOURCE_DIR)/linux-$(BASE_KVER).tar.bz2" ] && echo "OK" || echo "$(cmd_make) rootfs will fail."

ifneq ($(KVER),$(BASE_KVER))
	@echo -n "Checking kernel source patch-$(KVER).bz2 : "
	@[ -s "$(SOURCE_DIR)/patch-$(KVER).bz2" ] && echo "OK" || echo "$(cmd_make) rootfs may fail."
endif
	@echo -n "Checking cmd_gzip ($(cmd_gzip)) : "
	@$(cmd_gzip) -c9 </dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_bzip2 ($(cmd_bzip2)) : "
	@$(cmd_bzip2) -c9 </dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_sudo ($(cmd_sudo)) : "
	@$(cmd_sudo) true 2>/dev/null && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_cpio ($(cmd_cpio)) : "
	@echo /dev/null | $(cmd_cpio) -o -H newc >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_tar ($(cmd_tar)) : "
	@$(cmd_tar) -cf - /dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_install ($(cmd_install)) : "
	@$(cmd_install) --version >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_patch ($(cmd_patch)) : "
	@$(cmd_patch) --version >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_find ($(cmd_find)) : "
	@$(cmd_find) /dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_kgcc ($(cmd_kgcc)) : "
	@$(cmd_kgcc) -c -xc -o /dev/null /dev/null && echo "OK" || echo "Failed"
	@echo -n "Checking cmd_lzma ($(cmd_lzma)) : "
	@$(cmd_lzma) e -si -so </dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed. See doc/lzma-howto.txt"
	@echo -n "Checking cmd_make ($(cmd_make)) : "
	@$(cmd_make) --version >/dev/null 2>&1 && echo "OK" || echo "Failed"

clean:
	@[ -z "$(TEMP_FILES)" ] || rm -rf $(TEMP_FILES)

mrproper: clean
	$(cmd_sudo) rm -rf $(BUILD_DIR)

distclean: mrproper
	rm -f $(PERM_FILES)
	rm -rf $(FINAL_DIR)

# Undocumented 'reallyclean' also cleans the source directory !
reallyclean: distclean
	rm -rf $(SOURCE_DIR)


###########################################################################
## WARNING ! NO USER SERVICEABLE PARTS BELOW. RISK OF ELECTRIC SHOCK !!! ##
###########################################################################

############ now the "real" targets #############
#### rootfs (initramfs)
rootfs: $(INITRAMFS)

$(INITRAMFS): $(BUILD_DIR)/rootfs.installed
	@echo "Creating initramfs archive..."
	$(Q) mkdir -p $(FINAL_DIR)
	$(Q) for f in .preinit init dev bin/{,busybox,kexec,serial-load} \
	  bin/{update-boot-image,firmware-cli,grub-mbr-default}; do \
	    echo $$f; \
	done | \
	  (cd $(BUILD_DIR)/rootfs; $(cmd_sudo) $(cmd_cpio) -o -H newc) > $@

$(BUILD_DIR)/rootfs.installed: rootfs/scripts/preinit rootfs/prebuilt/init rootfs/prebuilt/busybox rootfs/prebuilt/grub-mbr-default rootfs/prebuilt/kexec-1.101.upx rootfs/scripts/firmware-cli  rootfs/scripts/serial-load rootfs/scripts/update-boot-image
	@echo "Installing initramfs files..."
	$(Q) mkdir -p $(BUILD_DIR)/rootfs
	$(Q) $(cmd_sudo) $(cmd_install) -d -o root -g root -m 755 \
	     $(BUILD_DIR)/rootfs/{dev,bin}
	$(Q) $(cmd_sudo) $(cmd_install)    -o root -g root -m 500 \
	     rootfs/scripts/preinit $(BUILD_DIR)/rootfs/.preinit
	$(Q) $(cmd_sudo) $(cmd_install)    -o root -g root -m 500 \
	     rootfs/prebuilt/init $(BUILD_DIR)/rootfs/init
	$(Q) $(cmd_sudo) $(cmd_install)    -o root -g root -m 511 \
	     rootfs/prebuilt/busybox rootfs/prebuilt/grub-mbr-default $(BUILD_DIR)/rootfs/bin/
	$(Q) $(cmd_sudo) $(cmd_install)    -o root -g root -m 500 \
	     rootfs/prebuilt/kexec-1.101.upx $(BUILD_DIR)/rootfs/bin/kexec
	$(Q) $(cmd_sudo) $(cmd_install)    -o root -g root -m 500 \
	     rootfs/scripts/{firmware-cli,serial-load,update-boot-image} $(BUILD_DIR)/rootfs/bin/
	$(Q) touch $@

#### kernel
# Note: This part is really tricky because it is used to iterate through
# all platforms by producing dynamic rules. The difficulty is then to get
# the platform's name back within the scripts, 
kernel: $(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%.img,$(PLATFORMS))

$(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%.img,$(PLATFORMS)): \
  $(FINAL_DIR)/firmware-$(FWVER)-%.img: $(KDIR)/output/firmware-$(FWVER)-%.img

	$(Q) cp $< $@
	@echo "Firmware $(FWVER) for $(patsubst $(FINAL_DIR)/firmware-$(FWVER)-%.img,%,$@) is available here :"
	@echo "  -> $(subst $(CURDIR)/,,$@)"

$(patsubst %,$(KDIR)/output/firmware-$(FWVER)-%.img,$(PLATFORMS)): \
  $(KDIR)/output/firmware-$(FWVER)-%.img: \
  kernel/$(KVER)/configs/config-$(KVER)-$(FWVER)-% \
  $(KDIR)/.patched $(KDIR)/prebuilt/initramfs_data.cpio
	@echo "Building firmware version $(FWVER) for $(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@)..."
	$(Q) rm -f $@
	$(Q) mkdir -p $(KDIR)/configs $(KDIR)/output
	$(Q) mkdir -p $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@)
	$(Q) cp $< $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%/.config,$@)
	@(cd $(KDIR); unset KBUILD_OUTPUT; $(cmd_make) mrproper;              \
	  export KBUILD_OUTPUT=$(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@);      \
	  echo "  - cleaning everything and updating config...";              \
	  $(cmd_make) clean ;                                                 \
	  $(cmd_make) oldconfig > $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,config-%.log,$@); \
	  echo "  - compiling kernel $(KVER) for $${KBUILD_OUTPUT##*/}...";   \
	  if $(cmd_make) bzImage                                              \
	        CC="$(cmd_kgcc)" cmd_lzmaramfs="$(cmd_lzma) e \$$< \$$@ -d19" \
	        cmd_gzip="$(cmd_7za) a -tgzip -mx9 -mpass=4 -so -si . <\$$< >\$$@" \
	     > $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,build-%.log,$@) 2>&1; then  \
	    ln $${KBUILD_OUTPUT}/arch/i386/boot/bzImage $@;                   \
	  else                                                                \
	    echo "Failed !!!"; echo ;                                         \
	    echo "Tail of output/build-$${KBUILD_OUTPUT##*/}.log :";          \
	    echo " ------ ";                                                  \
	    tail -10 $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,build-%.log,$@);      \
	    echo " ------ ";                                                  \
	    exit 1;                                                           \
	  fi)
	@echo "  -> done."

$(KDIR)/prebuilt/initramfs_data.cpio: $(KDIR)/.patched
	$(Q) if [ ! -s "$(INITRAMFS)" ]; then \
               echo "Missing rootfs : $(INITRAMFS)."; \
	       ! echo "  -> Please issue '$(cmd_make) rootfs' first."; \
             fi
	$(Q) mkdir -p $(KDIR)/prebuilt
	$(Q) rm -f $@ ; ln -s $(INITRAMFS) $@

$(KDIR)/.patched: $(KDIR)/.updated
	@echo "Patching kernel $(KVER)..."
	$(Q) $(cmd_find) $(CURDIR)/kernel/$(KVER)/patches -maxdepth 1 -type f \
	  -exec $(cmd_patch) -d $(KDIR) -Nsp1 -i \{\} \;
	touch $@
	@echo "  -> done."

# we may have to apply a patch to update the kernel to a more recent version
ifeq ($(KVER),$(BASE_KVER))
$(KDIR)/.updated: $(BUILD_DIR)/kernel/linux-$(BASE_KVER)/.extracted
	touch $@
else
$(KDIR)/.updated: $(BUILD_DIR)/kernel/linux-$(BASE_KVER)/.extracted $(SOURCE_DIR)/patch-$(KVER).bz2
	@echo "Updating kernel $(BASE_KVER) to $(KVER)..."
	$(Q) cp -al $(BUILD_DIR)/kernel/linux-$(BASE_KVER)/. $(KDIR);
	$(Q) $(cmd_bzip2) -cd $(SOURCE_DIR)/patch-$(KVER).bz2 | $(cmd_patch) -d $(KDIR) -Nsp1
	$(Q) touch $@
	@echo "  -> done."
endif

# here, we simply extract the kernel sources into the fresh new directory
$(BUILD_DIR)/kernel/linux-$(BASE_KVER)/.extracted: $(SOURCE_DIR)/linux-$(BASE_KVER).tar.bz2
	@echo "Extracting kernel $(BASE_KVER)..."
	$(Q) mkdir -p $(BUILD_DIR)/kernel
	$(Q) $(cmd_tar) -C $(BUILD_DIR)/kernel -jxf $<
	$(Q) touch $@
	@echo "  -> done."
