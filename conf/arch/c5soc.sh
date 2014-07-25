
TARGET_META_ARCH=armv7
MINIFS_BOARD_ROLE+=" c5soc"

TARGET_ARCH=arm
TARGET_FULL_ARCH=$TARGET_ARCH-a9-linux-gnueabi
TARGET_KERNEL_NAME=zImage
TARGET_LIBC_CFLAGS="-g -O2 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -fPIC -mthumb-interwork"
TARGET_CFLAGS="$TARGET_LIBC_CFLAGS"

c5soc-prepare() {
	hset linux version "3.09"
	hset linux url "git!git://git.rocketboards.org/linux-socfpga.git#linux-c5soc.tar.bz2"
	hset linux make-extra-parameters "LOADADDR=0x8000"
}


c5soc-configure-uboot() {
	configure-generic
}

c5soc-deploy-sharedlibs() {
#	cp "$BUILD/kernel.ub" "$ROOTFS"/
	deploy-sharedlibs
	if [ ! -e "$ROOTFS"/lib/ld-linux.so.3 ]; then
		echo "     Fixing armhf loader"
		ln -sf ld-linux-armhf.so.3 "$ROOTFS"/lib/ld-linux.so.3
	fi
	mkdir -p "$ROOTFS"/root
}
