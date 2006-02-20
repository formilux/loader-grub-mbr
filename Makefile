FWVER     = 0.3
BASE_KVER = 2.6.15
KVER      = 2.6.16-rc4

CURDIR        := $(shell pwd)
FINAL_DIR     := $(CURDIR)/image
BUILD_DIR     := $(CURDIR)/build
SOURCE_DIR    := $(CURDIR)/sources

INITRAMFS     := $(FINAL_DIR)/initramfs_data.cpio

KDIR          := $(BUILD_DIR)/kernel/linux-$(KVER)

TEMP_FILES    := 
PERM_FILES    := $(INITRAMFS)

# set to anything other than empty to see commands being executed
V =

# various commands

cmd_sudo      := sudo
cmd_gzip      := gzip
cmd_cpio      := cpio
cmd_tar       := tar
cmd_install   := install
cmd_path      := patch
cmd_bzip2     := bzip2
cmd_find      := find
cmd_patch     := patch
cmd_kgcc      := gcc-3.4
cmd_lzma      := lzma
cmd_make      := make

########################################################################

ifeq ($(V),)
  Q = @
else
  Q =
endif

######## end of configuration, beginning of the standard targets #######

help:
	@echo "Usage: make < rootfs | help | clean | mrproper | distclean >"
	@echo "  Use 'mrproper' to clean the 'build' directory and temp files."
	@echo "  Use 'distclean' to clean everything including final files."
	@echo

clean:
#	rm -f $(TEMP_FILES)

mrproper: clean
	$(cmd_sudo) rm -rf $(BUILD_DIR)

distclean: mrproper
	rm -f $(PERM_FILES)
	rm -rf $(FINAL_DIR)

reallyclean: distclean
	rm -rf $(SOURCE_DIR)

######## now the "real" targets ########

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
kernel: $(FINAL_DIR)/firmware-$(FWVER)-nsa1041.img

$(FINAL_DIR)/firmware-$(FWVER)-nsa1041.img: $(KDIR)/output/firmware-$(FWVER)-nsa1041.img
	$(Q) cp $< $@
	@echo "Firmware $(FWVER) for nsa1041 is available here :"
	@echo "  -> $@"

$(KDIR)/output/firmware-$(FWVER)-nsa1041.img: $(KDIR)/.patched $(KDIR)/prebuilt/initramfs_data.cpio kernel/$(KVER)/configs/config-$(KVER)-$(FWVER)-nsa1041
	@echo "Building firmware version $(FWVER) for nsa1041..."
	$(Q) rm -f $@
	$(Q) mkdir -p $(KDIR)/configs $(KDIR)/output
	$(Q) mkdir -p $(KDIR)/output/nsa1041
	$(Q) cp kernel/$(KVER)/configs/config-$(KVER)-$(FWVER)-nsa1041 $(KDIR)/output/nsa1041/.config
	@(cd $(KDIR); unset KBUILD_OUTPUT; $(cmd_make) mrproper;              \
	  export KBUILD_OUTPUT=$(KDIR)/output/nsa1041;                        \
	  echo "  - cleaning everything and updating config...";              \
	  $(cmd_make) -j 3 clean ; $(cmd_make) oldconfig;                     \
	  echo "  - compiling kernel $(KVER)...";                             \
	  if $(cmd_make) -j 3 bzImage                                         \
	        CC="$(cmd_kgcc)" cmd_lzmaramfs="$(cmd_lzma) e \$$< \$$@ -d19" \
	     > output/build-nsa1041.log 2>&1; then                            \
	    ln $${KBUILD_OUTPUT}/arch/i386/boot/bzImage $@;                   \
	  else                                                                \
	    echo "Failed !!!";                                                \
	    echo; echo "Tail of output/build-nsa1041.log :"; echo " ------ "; \
	    tail -10 output/build-nsa1041.log; echo " ------ ";               \
	    exit 1;                                                           \
	  fi)
	@echo "  -> done."

$(KDIR)/prebuilt/initramfs_data.cpio: $(INITRAMFS) $(KDIR)/.patched
	$(Q) mkdir -p $(KDIR)/prebuilt
	$(Q) rm -f $@ ; ln -s $< $@

$(KDIR)/.patched: $(KDIR)/.updated
	@echo "Patching kernel $(KVER)..."
	$(Q) $(cmd_find) $(CURDIR)/kernel/$(KVER)/patches -maxdepth 1 -type f \
	  -exec patch -d $(KDIR) -Nsp1 -i \{\} \;
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

