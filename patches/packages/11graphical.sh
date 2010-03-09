
PACKAGES+=" libpng"
hset url libpng "ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng-1.2.42.tar.bz2"
hset depends libpng "zlib"

PACKAGES+=" libfreetype"
hset url libfreetype "http://mirrors.aixtools.net/sv/freetype/freetype-2.3.12.tar.bz2"

PACKAGES+=" libfontconfig"
hset url libfontconfig "http://www.fontconfig.org/release/fontconfig-2.8.0.tar.gz"

configure-libfontconfig-local() {
#	sed -i -e "s:^CFLAGS = @CFLAGS@:CFLAGS =:g" \
#		fc-case/Makefile.in \
#		fc-cache/Makefile.in \
#		fc-lang/Makefile.in \
#		fc-glyphname/Makefile.in \
#		fc-arch/Makefile.in
	export LDFLAGS="$LDFLAGS_RLINK"
	autoreconf;libtoolize;automake --add-missing
	configure-generic-local \
		--with-arch=$TARGET_FULL_ARCH \
		--disable-docs 
	export LDFLAGS="$LDFLAGS_BASE"
}
configure-libfontconfig() {
	configure configure-libfontconfig-local
}

compile-libfontconfig() {
	export LDFLAGS="$LDFLAGS_RLINK -lfreetype -lz -lexpat"
	compile-generic V=1
	export LDFLAGS="$LDFLAGS_BASE"
}
deploy-libfontconfig() {
	deploy cp "$STAGING_USR"/bin/fc-* \
		"$ROOTFS"/usr/bin/
	rsync -av \
		"$STAGING_USR"/etc/fonts \
		"$ROOTFS"/usr/etc/ \
			&>> "$LOGFILE" 
}

PACKAGES+=" libpixman"
hset url libpixman "http://xorg.freedesktop.org/archive/individual/lib/pixman-0.17.6.tar.bz2"

configure-libpixman() {
	configure-generic \
		--disable-gtk
}

PACKAGES+=" libts"
hset url libts "http://download2.berlios.de/tslib/tslib-1.0.tar.bz2"

configure-libts-local() {
	configure-generic-local \
		--disable-linear-h2200 \
		--disable-ucb1x00 \
		--disable-corgi \
		--disable-collie \
		--disable-h3600 \
		--disable-mk712 \
		--disable-arctic2
	sed -i -e 's:^#define malloc rpl_malloc:// #define malloc rpl_malloc:g' config.h
}
configure-libts() {
	configure configure-libts-local
}

