# set to anything other than empty to see commands being executed
V =
NOCLEAN =

FWVER         = 3.2
BASE_KVER     = 3.10.104
KVER          = 3.10.104
GRUBVER       = 0.96
GENE2FSVER    = 1.4

SHELL 	      := /bin/bash

CURDIR        := $(shell pwd)
FINAL_DIR     := $(CURDIR)/image
BUILD_DIR     := $(CURDIR)/build
SOURCE_DIR    := $(CURDIR)/sources

INITRAMFS     := $(FINAL_DIR)/initramfs_data.cpio
INSTRAMFS_DIR := $(BUILD_DIR)/instramfs
INSTRAMFS_PFX := $(FINAL_DIR)/instramfs_data

KDIR          := $(BUILD_DIR)/kernel/linux-$(KVER)

TEMP_FILES    := $(KDIR)/output $(KDIR)/prebuilt/initramfs_data.cpio $(KDIR)/prebuilt/.data-kernel
PERM_FILES    := $(INITRAMFS)

# Use the kernel configuration names to determine the list of possible software
# platforms (1 sw platform = 1 kernel = 1 firmware.img).
SW_PLATFORMS  := $(shell x=( $$(echo kernel/$(KVER)/configs/config-$(KVER)-*) ); \
	           echo $${x[@]\#\#*-}|tr ' ' '\n'|sort -u )

# Use the boot loader configuration names to determine the list of possible
# hardware platforms, which must at least include the software ones.
HW_PLATFORMS  := $(shell x=( $$(echo loader/menu-*.lst) ); \
                   x=( $${x[@]\#loader/menu-} ); \
                   echo $${x[@]%.lst} | tr ' ' '\n' | sort -u )

# Platforms which will be built, default to all hardware platforms
PLATFORMS     := $(HW_PLATFORMS)

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
cmd_kgcc      := i586-flx-linux-gcc-3.4 # WARNING! gcc-4.0.[012] produces bad kexec code !
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
	@echo "Usage: make < help|check|rootfs|kernel|loader|clean|mrproper|distclean>"
	@echo
	@echo "  Supported platforms (may be reduced with 'PLATFORMS=xxx') :"
	@echo "      >> $(PLATFORMS) <<"
	@echo
	@echo "  Use 'check' to check your build environment."
	@echo "  Use 'mrproper' to clean the 'build' directory and temp files."
	@echo "  Use 'distclean' to clean everything including final files."
	@echo "  Use 'rootfs' FIRST to build only the initramfs."
	@echo "  Use 'kernel' to build the bootable kernel image for all platforms."
	@echo "  Use 'loader' to produce the GRUB FS and disk images for all platforms."
	@echo "  Use 'instfs' to embed the disk image in a new root FS for all platforms."
	@echo "  Use 'instimg' to build a new bootable image with the embedded FS."
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

	@echo -n "Checking grub source grub-$(GRUBVER).tar.bz2 : "
	@[ -s "$(SOURCE_DIR)/grub-$(GRUBVER).tar.bz2" ] && echo "OK" || echo "$(cmd_make) loader will fail."

	@echo -n "Checking genext2fs source genext2fs-$(GENE2FSVER).tar.bz2 : "
	@[ -s "$(SOURCE_DIR)/genext2fs-$(GENE2FSVER).tar.bz2" ] && echo "OK" || echo "$(cmd_make) loader will fail."

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
	@$(cmd_lzma) -9 -f - </dev/null >/dev/null 2>&1 && echo "OK" || echo "Failed. See doc/lzma-howto.txt"
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
	  bin/{mk-flash-layout,update-boot-image,firmware-cli,grub-mbr-default}; do \
	    echo $$f; \
	done | \
	  (cd $(BUILD_DIR)/rootfs; $(cmd_sudo) $(cmd_cpio) -o -H newc) > $@

$(BUILD_DIR)/rootfs.installed: rootfs/scripts/preinit rootfs/prebuilt/init rootfs/prebuilt/busybox rootfs/prebuilt/grub-mbr-default rootfs/prebuilt/kexec-1.101.upx rootfs/scripts/mk-flash-layout rootfs/scripts/firmware-cli rootfs/scripts/serial-load rootfs/scripts/update-boot-image
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
	     rootfs/scripts/{mk-flash-layout,firmware-cli,serial-load,update-boot-image} $(BUILD_DIR)/rootfs/bin/
	$(Q) touch $@

#### kernel
# Note: This part is really tricky because it is used to iterate through
# all platforms by producing dynamic rules. The difficulty is then to get
# the platform's name back within the scripts, 
kernel: $(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%.img,$(PLATFORMS))

# rack variant: it is simply the same as the original with a different menu.lst
$(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%-rack.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/firmware-$(FWVER)-%-rack.img: $(KDIR)/output/firmware-$(FWVER)-%.img
	ln -s $(patsubst $(KDIR)/output/%,%,$<) $@

# serial variant: it is simply the same as the original with a different menu.lst
$(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%-serial.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/firmware-$(FWVER)-%-serial.img: $(KDIR)/output/firmware-$(FWVER)-%.img
	ln -s $(patsubst $(KDIR)/output/%,%,$<) $@

$(patsubst %,$(FINAL_DIR)/firmware-$(FWVER)-%.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/firmware-$(FWVER)-%.img: $(KDIR)/output/firmware-$(FWVER)-%.img

	$(Q) cp $< $@
	@echo "Firmware $(FWVER) for $(patsubst $(FINAL_DIR)/firmware-$(FWVER)-%.img,%,$@) is available here :"
	@echo "  -> $(subst $(CURDIR)/,,$@)"

$(patsubst %,$(KDIR)/output/firmware-$(FWVER)-%.img,$(SW_PLATFORMS)): \
  $(KDIR)/output/firmware-$(FWVER)-%.img: \
  kernel/$(KVER)/configs/config-$(KVER)-% \
  $(KDIR)/.patched $(KDIR)/prebuilt/.data-kernel
	@echo "Building firmware version $(FWVER) for $(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@)..."
	$(Q) rm -f $@
	$(Q) mkdir -p $(KDIR)/configs $(KDIR)/output
	$(Q) mkdir -p $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@)
	$(Q) cp $< $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%/.config,$@)
	$(Q) ( \
          cd $(KDIR); unset KBUILD_OUTPUT; $(cmd_make) mrproper;              \
	  export KBUILD_OUTPUT=$(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,%,$@);      \
	  if [ -z "$(NOCLEAN)" ]; then \
	    echo "  - cleaning everything and updating config...";              \
	    $(cmd_make) clean ;                                                 \
	    $(cmd_make) oldconfig > $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,config-%.log,$@); \
	  fi; \
	  echo "  - compiling kernel $(KVER) for $${KBUILD_OUTPUT##*/}...";   \
	  if $(cmd_make) bzImage                                              \
	        CC="$(cmd_kgcc)" \
	        cmd_gzip="$(cmd_7za) a -tgzip -mx9 -mpass=4 -so -si . <\$$< >\$$@" \
	     > $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,build-%.log,$@) 2>&1; then  \
	    ln $${KBUILD_OUTPUT}/arch/x86/boot/bzImage $@;                   \
	  else                                                                \
	    echo "Failed !!!"; echo ;                                         \
	    echo "Tail of output/build-$${KBUILD_OUTPUT##*/}.log :";          \
	    echo " ------ ";                                                  \
	    tail -10 $(KDIR)/output/$(patsubst $(KDIR)/output/firmware-$(FWVER)-%.img,build-%.log,$@);      \
	    echo " ------ ";                                                  \
	    exit 1;                                                           \
	  fi \
        )
	@echo "  -> done."

$(KDIR)/prebuilt/.data-kernel: $(KDIR)/.patched
	$(Q) if [ ! -s "$(INITRAMFS)" ]; then \
               echo "Missing rootfs : $(INITRAMFS)."; \
	       ! echo "  -> Please issue '$(cmd_make) rootfs' first."; \
             fi
	$(Q) mkdir -p $(KDIR)/prebuilt

	$(Q) rm -f $(KDIR)/prebuilt/.data-* $(KDIR)/prebuilt/initramfs_data.cpio
	$(Q) ln -s $(INITRAMFS) $(KDIR)/prebuilt/initramfs_data.cpio
	$(Q) touch $@

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


#### loader

loader: $(patsubst %,$(FINAL_DIR)/bootstrap-$(FWVER)-%.fs,$(PLATFORMS))

$(patsubst %,$(FINAL_DIR)/bootstrap-$(FWVER)-%.fs,$(HW_PLATFORMS)): \
$(FINAL_DIR)/bootstrap-$(FWVER)-%.fs: $(FINAL_DIR)/firmware-$(FWVER)-%.img \
	$(BUILD_DIR)/tools/grub-$(GRUBVER)/grub/grub \
	$(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/genext2fs \
	./loader/create-part

	$(Q) ./loader/create-part $(FINAL_DIR) $(FWVER) \
	    $(patsubst $(FINAL_DIR)/bootstrap-$(FWVER)-%.fs,%,$@) $(BUILD_DIR) \
	    $(BUILD_DIR)/tools/grub-$(GRUBVER)/grub/grub \
	    $(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/genext2fs

	@echo "Bootstrap $(FWVER) for $(patsubst $(FINAL_DIR)/bootstrap-$(FWVER)-%.fs,%,$@) is available here :"
	@echo "  -> $(FINAL_DIR)/bootstrap-$(FWVER)-*.{fs,dsk}"


#### tools

# 1) grub
$(BUILD_DIR)/tools/grub-$(GRUBVER)/.extracted: $(SOURCE_DIR)/grub-$(GRUBVER).tar.bz2
	@echo "Extracting grub $(GRUBVER)..."
	$(Q) mkdir -p $(BUILD_DIR)/tools
	$(Q) $(cmd_tar) -C $(BUILD_DIR)/tools -jxf $<
	$(Q) touch $@
	@echo "  -> done."

$(BUILD_DIR)/tools/grub-$(GRUBVER)/.configured: $(BUILD_DIR)/tools/grub-$(GRUBVER)/.extracted
	@echo "Configuring grub $(GRUBVER)..."
	$(Q) ( \
	  cd $(BUILD_DIR)/tools/grub-$(GRUBVER); \
	  CC=$(cmd_kgcc) \
	  ./configure  --host=i586-linux-gnu \
		       --disable-fat --disable-ffs --disable-ufs2 --disable-minix \
	               --disable-reiserfs --disable-vstafs --disable-jfs --disable-xfs \
	               --disable-iso9660 --disable-gunzip --disable-md5-password \
	               --without-curses --disable-hercules --disable-serial \
	)
	$(Q) touch $@
	@echo "  -> done."

$(BUILD_DIR)/tools/grub-$(GRUBVER)/grub/grub: $(BUILD_DIR)/tools/grub-$(GRUBVER)/.configured
	@echo "Building grub $(GRUBVER)..."
	$(Q) (cd $(BUILD_DIR)/tools/grub-$(GRUBVER); $(cmd_make) )
	$(Q) strip $@
	@echo "  -> done."


# 2) genext2fs
$(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/.extracted: $(SOURCE_DIR)/genext2fs-$(GENE2FSVER).tar.bz2
	@echo "Extracting grub $(GENE2FSVER)..."
	$(Q) mkdir -p $(BUILD_DIR)/tools
	$(Q) $(cmd_tar) -C $(BUILD_DIR)/tools -jxf $<
	$(Q) touch $@
	@echo "  -> done."

$(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/.configured: $(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/.extracted
	@echo "Configuring genext2fs $(GENE2FSVER)..."
	$(Q) ( \
	  cd $(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER); \
	 ( [ -e configure ] || ./autogen.sh ) && CC=$(cmd_kgcc)  ./configure --host=i386-linux \
	)
	$(Q) touch $@
	@echo "  -> done."

$(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/genext2fs: $(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER)/.configured
	@echo "Configuring genext2fs $(GENE2FSVER)..."
	$(Q) (cd $(BUILD_DIR)/tools/genext2fs-$(GENE2FSVER); $(cmd_make) )
	$(Q) strip $@
	@echo "  -> done."

#### instfs (initramfs)

instfs: $(patsubst %,$(INSTRAMFS_PFX)-%.cpio,$(PLATFORMS))

$(patsubst %,$(INSTRAMFS_PFX)-%.cpio,$(HW_PLATFORMS)): \
  $(INSTRAMFS_PFX)-%.cpio: $(INSTRAMFS_DIR)/.installed/%
	@echo "Creating initramfs archive..."
	$(Q) mkdir -p $(FINAL_DIR)
	$(Q) for f in .preinit init dev bin/{,busybox,kexec,serial-load} \
	  bin/{mk-flash-layout,update-boot-image,firmware-cli,grub-mbr-default} \
	  $$(cd $(INSTRAMFS_DIR)/$(^F) && echo images images/*); do \
	    echo $$f; \
	done | \
	  (cd $(INSTRAMFS_DIR)/$(^F); $(cmd_sudo) $(cmd_cpio) -o -H newc) > $@

$(patsubst %,$(INSTRAMFS_DIR)/.installed/%,$(HW_PLATFORMS)): \
  $(INSTRAMFS_DIR)/.installed/%: $(FINAL_DIR)/bootstrap-$(FWVER)-%.fs $(BUILD_DIR)/rootfs.installed
	@echo "Creating instfs archive..."
	$(Q) mkdir -p $(@D)
	$(Q) $(cmd_sudo) mkdir -p $(INSTRAMFS_DIR)/$(@F) $(INSTRAMFS_DIR)/$(@F)/images
	$(Q) $(cmd_sudo) cp -a $(BUILD_DIR)/rootfs/. $(INSTRAMFS_DIR)/$(@F)/
	$(Q) $(cmd_sudo) cp $(FINAL_DIR)/bootstrap-$(FWVER)-$(@F).dsk $(INSTRAMFS_DIR)/$(@F)/images/
	$(Q) touch $@

#### instimg (kernel)
# Note: This part is really tricky because it is used to iterate through
# all platforms by producing dynamic rules. The difficulty is then to get
# the platform's name back within the scripts, 
instimg: $(patsubst %,$(FINAL_DIR)/instimg-$(FWVER)-%.img,$(PLATFORMS))

# Right now we cannot build installation images for HW platforms which are
# derived from SW platforms. Report it without failing the whole process.
$(patsubst %,$(FINAL_DIR)/instimg-$(FWVER)-%-rack.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/instimg-$(FWVER)-%-rack.img:
	@echo "Installation image for HW platform $(patsubst $(FINAL_DIR)/instimg-$(FWVER)-%.img,%,$@) will not be built."

# Right now we cannot build installation images for HW platforms which are
# derived from SW platforms. Report it without failing the whole process.
$(patsubst %,$(FINAL_DIR)/instimg-$(FWVER)-%-serial.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/instimg-$(FWVER)-%-serial.img:
	@echo "Installation image for HW platform $(patsubst $(FINAL_DIR)/instimg-$(FWVER)-%.img,%,$@) will not be built."

$(patsubst %,$(FINAL_DIR)/instimg-$(FWVER)-%.img,$(SW_PLATFORMS)): \
  $(FINAL_DIR)/instimg-$(FWVER)-%.img: $(KDIR)/output/instimg-$(FWVER)-%.img

	$(Q) cp $< $@
	@echo "Install image $(FWVER) for $(patsubst $(FINAL_DIR)/instimg-$(FWVER)-%.img,%,$@) is available here :"
	@echo "  -> $(subst $(CURDIR)/,,$@)"

# Note that here we're reusing the kernel build directory of a previous image,
# but we may not have a matching between hardware and software platforms.
$(patsubst %,$(KDIR)/output/instimg-$(FWVER)-%.img,$(SW_PLATFORMS)): \
  $(KDIR)/output/instimg-$(FWVER)-%.img: \
  kernel/$(KVER)/configs/config-$(KVER)-% \
  $(KDIR)/.patched $(KDIR)/prebuilt/.data-instimg-%
	@echo "Building instimg version $(FWVER) for $(patsubst $(KDIR)/output/instimg-$(FWVER)-%.img,%,$@)..."
	$(Q) rm -f $@
	@(cd $(KDIR); unset KBUILD_OUTPUT; $(cmd_make) mrproper;              \
	  export KBUILD_OUTPUT=$(KDIR)/output/$(patsubst $(KDIR)/output/instimg-$(FWVER)-%.img,%,$@);      \
	  echo "  - rebuilding kernel $(KVER) for $${KBUILD_OUTPUT##*/}...";   \
	  if $(cmd_make) bzImage                                              \
	        CC="$(cmd_kgcc)" \
	        cmd_gzip="$(cmd_7za) a -tgzip -mx9 -mpass=4 -so -si . <\$$< >\$$@" \
	     > $(KDIR)/output/$(patsubst $(KDIR)/output/instimg-$(FWVER)-%.img,instimg-%.log,$@) 2>&1; then  \
	    ln $${KBUILD_OUTPUT}/arch/x86/boot/bzImage $@;                   \
	  else                                                                \
	    echo "Failed !!!"; echo ;                                         \
	    echo "Tail of output/instimg-$${KBUILD_OUTPUT##*/}.log :";        \
	    echo " ------ ";                                                  \
	    tail -10 $(KDIR)/output/$(patsubst $(KDIR)/output/instimg-$(FWVER)-%.img,instimg-%.log,$@);      \
	    echo " ------ ";                                                  \
	    exit 1;                                                           \
	  fi)
	@echo "  -> done."

$(patsubst %,$(KDIR)/prebuilt/.data-instimg-%,$(HW_PLATFORMS)): \
  $(KDIR)/prebuilt/.data-instimg-%:
	$(Q) if [ ! -s "$(INSTRAMFS_PFX)-$(patsubst $(KDIR)/prebuilt/.data-instimg-%,%,$@).cpio" ]; then \
               echo "Missing instfs : $(INSTRAMFS_PFX)-$(patsubst $(KDIR)/prebuilt/.data-instimg-%,%,$@).cpio."; \
	       ! echo "  -> Please issue '$(cmd_make) instfs' first."; \
             fi
	$(Q) mkdir -p $(KDIR)/prebuilt

	$(Q) rm -f $(KDIR)/prebuilt/.data-* $(KDIR)/prebuilt/initramfs_data.cpio
	$(Q) ln -s $(INSTRAMFS_PFX)-$(patsubst $(KDIR)/prebuilt/.data-instimg-%,%,$@).cpio $(KDIR)/prebuilt/initramfs_data.cpio
	$(Q) touch $@

.PHONY: help check clean mrproper distclean rootfs kernel loader
