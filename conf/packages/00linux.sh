#######################################################################
## contains the 4 main phases of compiling the kernel
#######################################################################

LINUX_VERSION=$(hget linux version)
LINUX_URL=$(echo $LINUX_VERSION| awk -F[.-] --source '{
printf("http://www.kernel.org/pub/linux/kernel/v%s%s/linux-%s.tar.xz\n",
       $1 == "3" ? "3.x" : ($1 "." $2),
       $NF ~ /^[0-9]+/ ? "" : "/testing",
       $0); }')
hset linux url $LINUX_URL

hset linux targets "linux-headers linux-modules linux-bare linux-initrd linux-dtb"

hset linux-headers dir "linux"
hset linux-modules dir "linux"
hset linux-bare dir "linux"
hset linux-initrd dir "linux"
hset linux-dtb dir "linux"

# the headers gets installed first, the other phases are later
PACKAGES+=" linux-headers"

export TARGET_KERNEL_ARCH="${TARGET_KERNEL_ARCH:-$TARGET_ARCH}"

linux-get-cross() {
	local cross=$(hget linux cross-prefix)
	echo "${cross:-${CROSS}}-"
}

#######################################################################
## linux-headers
#######################################################################

setup-linux-headers() {
	mkdir -p "$BUILD/linux-obj"
	local conf=$(minifs_locate_config_path config_kernel.conf)
	[[ "$conf" == "" ]] && conf="$CONFIG/config_kernel.conf"
	if [ "$COMMAND_PACKAGE" = "kernel" -o "$COMMAND_PACKAGE" = "linux" ] ; then
		if [ -f "$conf" ]; then
			cp "$conf"  "$BUILD/linux-obj"/.config
		fi
		$MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
			CROSS_COMPILE=$(linux-get-cross) \
				$COMMAND_TARGET
		if [ -f "$BUILD/linux-obj/.config" ]; then
			cp "$BUILD/linux-obj/.config" "$conf"
		fi
		rm -f ._*
		exit
	fi
	if [ ! -f "$BUILD/linux-obj/.config-bare" -o \
		"$conf" -nt "$BUILD/linux-obj/.config-bare" ]; then
		sed -e "s/CONFIG_INITRAMFS_SOURCE=.*/CONFIG_INITRAMFS_SOURCE=\"\"/" \
			"$conf" \
			>"$BUILD"/linux-obj/.config-bare
		rm -f ._conf_linux-headers
	fi
	ln -sf ".config-bare" "$BUILD/linux-obj/.config"
}

configure-linux-headers() {
	configure echo Done
}

compile-linux-headers() {
	compile $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
			oldconfig
}

install-linux-headers-local() {
	$MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		INSTALL_HDR_PATH="$KERNEL" \
			headers_install
	rm -rf "$STAGING_USR"/include/linux || true
	ln -s "$KERNEL"/include/linux \
		"$STAGING_USR"/include/linux || true
}

install-linux-headers() {
	log_install install-linux-headers-local
}

#######################################################################
## linux-modules
#######################################################################
if [ "$CONFIG_MODULES" != "" ]; then
	PACKAGES+=" linux-modules"
fi

hset linux-modules depends "linux-headers crosstools rootfs-create"

setup-linux-modules() {
	if [ "$BUILD/linux-obj/.config-bare" -nt ._conf_linux-bare ]; then
		rm -f ._conf_linux-modules ._conf_linux-bare
	fi
}

configure-linux-modules() {
	configure echo Done
}

compile-linux-modules() {
	compile $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		$(hget linux make-extra-parameters) \
			modules -j$MINIFS_JOBS
}

install-linux-modules() {
	log_install $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		INSTALL_HDR_PATH="$KERNEL" INSTALL_MOD_PATH="$KERNEL" \
			modules_install
}
deploy-linux-modules() {
	deploy rsync -a --exclude source --exclude build "$KERNEL"/lib "$ROOTFS/"
	find "$ROOTFS"/lib/modules/ -name \*.ko | \
		xargs "$(linux-get-cross)strip" -R .note -R .comment --strip-unneeded
}

#######################################################################
## linux-bare
#######################################################################

PACKAGES+=" linux-bare"
hset linux-bare depends "linux-modules linux-headers crosstools"

hostcheck-linux-bare() {
	if [ "$TARGET_KERNEL_NAME" == uImage ]; then
		hostcheck_commands mkimage
	fi
}
configure-linux-bare() {
	configure echo Done
}
compile-linux-bare() {
	compile $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		$(hget linux make-extra-parameters) \
			$TARGET_KERNEL_NAME -j$MINIFS_JOBS
}
install-linux-bare() {
	log_install $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		INSTALL_PATH="$KERNEL" INSTALL_MOD_PATH="$KERNEL" \
		INSTALLKERNEL="no-default-install" \
			install
}
deploy-linux-bare-local() {
	if [ -f "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/uImage ]; then
		dd if="$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/uImage \
			of="$BUILD"/kernel.ub \
			bs=128k conv=sync
	fi
	if [ -f "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/$TARGET_KERNEL_NAME ]; then
		cp "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/$TARGET_KERNEL_NAME \
			"$BUILD"/vmlinuz-bare.bin
	fi
	if [ -f "$BUILD"/linux-obj/$TARGET_KERNEL_NAME ]; then
		cp "$BUILD"/linux-obj/$TARGET_KERNEL_NAME \
			"$BUILD"/$TARGET_KERNEL_NAME-bare.bin
	fi
}

deploy-linux-bare() {
	deploy deploy-linux-bare-local
}

#######################################################################
## linux-initrd
#######################################################################
if [ $TARGET_INITRD -eq 1 ]; then
	PACKAGES+=" linux-initrd"
fi
hset linux-initrd depends "filesystems"
hset linux-initrd phases "deploy"

setup-linux-initrd() {
	ROOTFS_INITRD="../rootfs"
	optional_one_of \
		$MINIFS_BOARD-setup-initrd \
		setup-initrd || break
	mkdir -p "$BUILD/linux-obj"
	touch ._conf_linux-initrd
	local conf=$(minifs_locate_config_path config_kernel.conf)
	[[ "$conf" == "" ]] && conf="$CONFIG/config_kernel.conf"
	if [ ! -f "$BUILD/linux-obj/.config-initrd" -o \
		"$conf" -nt "$BUILD/linux-obj/.config-initrd" ]; then
		sed -e "s|CONFIG_INITRAMFS_SOURCE=.*|CONFIG_INITRAMFS_SOURCE=\"$ROOTFS_INITRD ../staging-tools/special_file_table_kernel.txt\"|" \
			"$conf" \
			>"$BUILD"/linux-obj/.config-initrd
		rm -f ._conf_linux-initrd
	fi
	ln -sf ".config-initrd" "$BUILD/linux-obj/.config"
}

configure-linux-initrd() {
	configure $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
			oldconfig >>"$LOGFILE" 2>&1
}

compile-linux-initrd() {
	rm -f "$BUILD/linux-obj"/usr/initramfs_data.*
	compile $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		$(hget linux make-extra-parameters) \
			$TARGET_KERNEL_NAME -j$MINIFS_JOBS
}
install-linux-initrd() {
	log_install $MAKE CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) \
		INSTALL_PATH="$KERNEL" INSTALL_MOD_PATH="$KERNEL" \
		INSTALLKERNEL="no-default-install" \
			install
}

deploy-linux-initrd() {
	setup-linux-initrd && \
		configure-linux-initrd && \
		compile-linux-initrd && \
		install-linux-initrd
	if [ -f "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/bzImage ]; then
		deploy cp "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/bzImage \
			"$BUILD"/vmlinuz-full.bin
	elif [ -f "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/$TARGET_KERNEL_NAME ]; then
		deploy cp "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/$TARGET_KERNEL_NAME \
			"$BUILD"/vmlinuz-full.bin
	elif [ -f "$BUILD"/linux-obj/arch/$TARGET_KERNEL_ARCH/boot/uImage ]; then
		deploy dd if="$BUILD"/linux-obj/arch/arm/boot/uImage \
			of="$BUILD"/kernel-initrd.ub \
			bs=128k conv=sync
	elif [ -f "$BUILD"/linux-obj/$TARGET_KERNEL_NAME ]; then
		deploy cp "$BUILD"/linux-obj/$TARGET_KERNEL_NAME \
			"$BUILD"/$TARGET_KERNEL_NAME-full.bin
	fi
}

#######################################################################
## linux-dtb
#
# This bit compiles a device tree file from a source that is either
# in the board config directory, or in the linux source tree itself
# it gets compiled witht he 'dtc' tool that is made at the same time
# as the kernel, and then gets concatenated to the kernel to create
# a vmlinuz-xxx.dtb file
#######################################################################
echo TARGET_KERNEL_DTB $TARGET_KERNEL_DTB
if [ "$TARGET_KERNEL_DTB" != "" ]; then
	PACKAGES+=" linux-dtb"
fi
hset linux-dtb depends "linux-bare linux-initrd"
hset linux-dtb phases "deploy"

deploy-linux-dtb-local() {
	set -x
	local dtb="$BUILD"/device-tree.dtb
	local source=$(minifs_locate_config_path "$TARGET_KERNEL_DTB".dts)

	for src in $source \
			"$BUILD/linux/arch/$TARGET_KERNEL_ARCH/boot/dts/$TARGET_KERNEL_DTB".dts \
			"$TARGET_KERNEL_DTB"; do
		if [ -f "$src" ]; then
			source=$src
		fi
	done
	echo DTB is $source
	cat $source	| $GCC -E -P -x assembler-with-cpp - \
			-I $(dirname $source) \
			-I "$BUILD/linux/arch/$TARGET_KERNEL_ARCH/boot/dts/" | tee /tmp/debug.dts | \
		"$BUILD"/linux-obj/scripts/dtc/dtc -O dtb \
			-i "$BUILD/linux/arch/$TARGET_KERNEL_ARCH/boot/dts/" \
			-o $dtb || return 1

	rm -f "$BUILD"/vmlinuz-bare.dtb
	if [ -f "$BUILD"/vmlinuz-bare.bin -a -f "$dtb" ]; then
		cat "$BUILD"/vmlinuz-bare.bin "$dtb" >"$BUILD"/vmlinuz-bare.dtb
		hset linux-dtb filename "$BUILD"/vmlinuz-bare.dtb
	fi
	set +x
}
deploy-linux-dtb() {
	touch ._install_$PACKAGE
	deploy deploy-linux-dtb-local
}

PACKAGES+=" linux-firmware"
hset linux-firmware url "git!git://git.kernel.org/pub/scm/linux/kernel/git/dwmw2/linux-firmware.git#linux-firmware-121119-git.tar.bz2"
hset linux-firmware depends "linux-modules"
hset linux-firmware phases "none"

#
# linux-perf is the perf tool that is present in th kernel tree. Unfortunately
# it requires a much recent/different libelf than what is compiled by crosstool-ng
# and 'elftools' are a royal pain in the proverbial to cross-compile.
# So, this is work in progress
#
PACKAGES+=" linux-perf"
hset linux-perf dir "linux/tools/perf"
hset linux-perf depends "busybox linux-bare libnewt"

configure-linux-perf() {
	configure sed -i -e 's|"../../include|"../../../include|' ./util/evsel.c
}

compile-linux-perf() {
	compile $MAKE EXTRA_CFLAGS="$TARGET_CFLAGS" ARCH=$TARGET_KERNEL_ARCH O="$BUILD/linux-obj" \
		CROSS_COMPILE=$(linux-get-cross) V=1 \
		WERROR=0 NO_GTK2=1 NO_LIBPERL=1 NO_LIBPYTHON=1
}

deploy-linux-perf() {
	deploy deploy_binaries
}

PACKAGES+=" firmware-rtl"
hset firmware-rtl depends "linux-firmware"
hset firmware-rtl dir "linux-firmware"
hset firmware-rtl url "none"
hset firmware-rtl phases "deploy"
hset firmware-rtl subdirs "rtl_nic rtlwifi"

deploy-firmware-rtl-local() {
	mkdir "$ROOTFS"/lib/firmware
	cp -r $(hget firmware-rtl subdirs) "$ROOTFS"/lib/firmware/
}
deploy-firmware-rtl() {
	if [ ! -f "._install_$PACKAGE" ]; then
		touch "._install_$PACKAGE"
	fi
	deploy deploy-firmware-rtl-local
}

PACKAGES+=" firmware-ralink"
hset firmware-ralink depends "linux-firmware"
hset firmware-ralink dir "linux-firmware"
hset firmware-ralink url "none"
hset firmware-ralink phases "deploy"

deploy-firmware-ralink-local() {
	mkdir "$ROOTFS"/lib/firmware
	cp -r rt*.bin "$ROOTFS"/lib/firmware/
}
deploy-firmware-ralink() {
	if [ ! -f "._install_$PACKAGE" ]; then
		touch "._install_$PACKAGE"
	fi
	deploy deploy-firmware-ralink-local
}

PACKAGES+=" kexec-tools"
hset kexec-tools url "http://kernel.org/pub/linux/utils/kernel/kexec/kexec-tools-2.0.3.tar.xz"
hset kexec-tools depends "busybox"

deploy-kexec-tools() {
	mkdir -p "$ROOTFS"/sbin/
	deploy cp "$STAGING_USR"/sbin/kexec "$ROOTFS"/sbin/
}

