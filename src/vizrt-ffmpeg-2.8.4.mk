# This file is part of MXE. See LICENSE.md for licensing information.

PKG             := vizrt-ffmpeg-2.8.4
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2.8.4
$(PKG)_CHECKSUM := 83cc8136a7845546062a43cda9ae3cf0a02f43ef5e434d2f997f055231a75f8e
$(PKG)_SUBDIR   := ffmpeg-2.8.4
$(PKG)_FILE     := ffmpeg-2.8.4.tar.bz2
$(PKG)_URL      := http://svn.vizrt.internal/svn/3rdpartyarchives/ffmpeg/ffmpeg-2.8.4.tar.bz2
$(PKG)_DEPS     := gcc bzip2 gnutls lame libass libbluray libbs2b libcaca \
                   libvpx opencore-amr opus sdl speex theora vidstab \
                   vo-amrwbenc vorbis vizrt-x264-20141218 xvidcore yasm zlib fdk-aac

define $(PKG)_UPDATE
    $(WGET) -q -O- 'http://ffmpeg.org/releases/' | \
    $(SED) -n 's,.*ffmpeg-\([0-9][^>]*\)\.tar.*,\1,p' | \
    grep -v 'alpha\|beta\|rc\|git' | \
    $(SORT) -Vr | \
    head -1
endef

define $(PKG)_BUILD
    cd '$(1)' && ./configure \
        --cross-prefix='$(TARGET)'- \
        --enable-cross-compile \
        --arch=$(firstword $(subst -, ,$(TARGET))) \
        --target-os=mingw32 \
        --prefix='$(PREFIX)/$(TARGET)' \
        $(if $(BUILD_STATIC), \
            --enable-static --disable-shared , \
            --disable-static --enable-shared ) \
        --yasmexe='$(TARGET)-yasm' \
        --disable-debug \
        --enable-memalign-hack \
        --disable-pthreads \
        --enable-w32threads \
        --disable-doc \
        --enable-avresample \
        --enable-version3 \
        --extra-libs='-mconsole' \
        --enable-avisynth \
        --enable-gnutls \
        --enable-libass \
        --enable-libbluray \
        --enable-libbs2b \
        --enable-libcaca \
        --enable-libmp3lame \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopus \
        --enable-libspeex \
        --enable-libtheora \
        --enable-libvo-amrwbenc \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-runtime-libx264 \
        --enable-libfdk-aac
    $(MAKE) -C '$(1)' -j '$(JOBS)'
    $(MAKE) -C '$(1)' -j 1 install
endef
