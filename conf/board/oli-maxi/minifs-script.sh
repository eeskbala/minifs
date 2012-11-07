#!/bin/bash

TARGET_META_ARCH=armv5

TARGET_ARCH=arm
TARGET_FULL_ARCH=$TARGET_ARCH-v5-linux-uclibcgnueabi
TARGET_KERNEL_NAME=zImage
TARGET_LIBC_CFLAGS="-g -O2 -mcpu=arm926ej-s -fPIC"
TARGET_CFLAGS="$TARGET_LIBC_CFLAGS -fPIC"


board_set_versions() {
	hset linux version "3.7-rc4"
	TARGET_FS_SQUASH=0
	TARGET_FS_EXT2=1
	TARGET_SHARED=1 
#	TARGET_X11=1
	#TARGET_INITRD=1
	NEEDED_HOST_COMMANDS+=" mkimage"
}

board_prepare() {
	TARGET_PACKAGES+=" gdbserver strace"
#	TARGET_PACKAGES+=" libusb "
	TARGET_PACKAGES+=" curl"

	TARGET_PACKAGES+=" targettools "	
}
