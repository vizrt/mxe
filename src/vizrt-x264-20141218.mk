# This file is part of MXE. See LICENSE.md for licensing information.

X264_DATE       := 20141218
PKG             := vizrt-x264-$(X264_DATE)
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 20141218
$(PKG)_CHECKSUM := 36f3c9c8dfa9a7399ae1aeaaecc9e05bb1a95764a1962c51296cb6d83c6c398b
$(PKG)_SUBDIR   := x264-snapshot-$(X264_DATE)-2245
$(PKG)_FILE     := $($(PKG)_SUBDIR).tar.bz2
$(PKG)_URL      := http://svn.vizrt.internal/svn/3rdpartyarchives/x264/$($(PKG)_FILE)
$(PKG)_DEPS     := gcc yasm liblsmash

define $(PKG)_UPDATE
    $(WGET) -q -O- 'http://git.videolan.org/?p=x264.git;a=shortlog' | \
    $(SED) -n 's,.*\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\).*,\1\2\3-2245,p' | \
    sort | \
    tail -1
endef

define $(PKG)_BUILD
    $(SED) -i 's,yasm,$(TARGET)-yasm,g' '$(1)/configure'
    cd '$(1)' && \
        ./configure \
        --extra-ldflags="-Wl,--output-def,x264.def" \
        $(MXE_CONFIGURE_OPTS) \
        --cross-prefix='$(TARGET)'- \
        --enable-win32thread \
        --disable-lavf \
        --disable-swscale   # Avoid circular dependency with ffmpeg. Remove if undesired.
    $(MAKE) -C '$(1)' -j 1 uninstall
    $(MAKE) -C '$(1)' -j '$(JOBS)'
    $(MAKE) -C '$(1)' -j 1 install

    $(TARGET)-dlltool -l $(PREFIX)/$(TARGET)/bin/x264.lib -d $(1)/x264.def -D libx264-148.dll
endef
