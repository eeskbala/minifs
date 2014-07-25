
. "$CONF_BASE"/arch/c5soc.sh

TARGET_LIBC=eglibc

TARGET_META_ARCH=armv7
TARGET_ARCH=arm
TARGET_FULL_ARCH=$TARGET_ARCH-a9-linux-gnueabi
TARGET_KERNEL_NAME=uImage
TARGET_LIBC_CFLAGS="-g -O2 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -fPIC -mthumb-interwork"
TARGET_CFLAGS="$TARGET_LIBC_CFLAGS"
# this file .dts must exist either in this directory (board)
# or in the linux arch/$TARGET_ARCH/boot/dts/
TARGET_KERNEL_DTB=${TARGET_KERNEL_DTB:-socfpga_cyclone5_sockit}

TARGET_FS_EXT=0
#TARGET_FS_TAR=0
TARGET_FS_SQUASH=1

board_set_versions() {
	TARGET_SHARED=1
	TARGET_INITRD=1
#	TARGET_X11=1
}

board_prepare() {
	c5soc-prepare
	TARGET_PACKAGES+=" gdbserver strace catchsegv"
	TARGET_PACKAGES+=" ethtool"
	TARGET_PACKAGES+=" curl rsync"
#	TARGET_PACKAGES+=" openssh sshfs mDNSResponder"

	TARGET_PACKAGES+=" i2c mtd_utils "
	hset mtd_utils deploy-list "nandwrite mtd_debug"

	TARGET_PACKAGES+=" targettools"

	TARGET_PACKAGES+=" libalsa"

	ROOTFS_KEEPERS+="libnss_compat.so.2:"
	ROOTFS_KEEPERS+="libnss_files.so.2:"
	export ROOTFS_KEEPERS

}
sockit-setup-initrd() {
	mkdir -p $BUILD/initramfs
	rm -rf $BUILD/initramfs/*
	ROOTFS_INITRD="../initramfs"
	echo  " Building trampoline $ROOTFS_INITRD"
	(
		(
			cd $BUILD/busybox
			echo Reinstalling busybox there
			ROOTFS=$ROOTFS_INITRD
			deploy-busybox-local
		)
		mkdir -p $STAGING/static/bin
		make -C $CONF_BASE/target-tools \
			STAGING=$STAGING/static MY_CFLAGS="-static -Os -std=gnu99"\
			TOOLS="waitfor_uevent fat_find" && \
			sstrip $STAGING/static/bin/* && \
			cp $STAGING/static/bin/* \
				$ROOTFS_INITRD/bin/
	)>$BUILD/._initramfs.log
	(
		cd $BUILD/initramfs/
		for pd in $(minifs_locate_config_path initramfs 1); do
			if [ -d "$pd" ]; then
				echo "### Installing initramfs $pd"
				rsync -av --exclude=._\* "$pd/" "./"
			fi
		done
	) >>$BUILD/._initramfs.log
}
