#!/bin/bash

TARGET_ARCH=arm
TARGET_FULL_ARCH=$TARGET_ARCH-v4t-linux-uclibcgnueabi
TARGET_KERNEL_NAME=uImage
TARGET_CFLAGS="-Os -march=armv4t -mtune=arm920t -mthumb-interwork -mthumb "

board_set_versions() {
	hset linux version "2.6.32.7"
	# for a >64Mb nand with 2k blocks and 128k erase blocks
#	TARGET_FS_JFFS2="-q -l -p -e 0x20000 -s 0x800"
	TARGET_INITRD=1
	hset uboot url "git!git://repo.or.cz/u-boot-openmoko/mini2440.git#uboot-mini2440-git.tar.bz2"
}

board_prepare() {
	TARGET_PACKAGES+=" uboot"
}

mini2440-deploy-uboot() {
	# make sure the u-boot is aligned on 2k blocks, for mtd_debug
	deploy dd if=u-boot.bin of="$BUILD"/u-boot.bin bs=2048 conv=sync
}

