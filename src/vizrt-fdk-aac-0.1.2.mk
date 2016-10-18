# This file is part of MXE. See LICENSE.md for licensing information.

PKG             := vizrt-fdk-aac-0.1.2
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 0.1.2
$(PKG)_CHECKSUM := 21901233fde347c432deabe557810e517d785a817ee51fffe50e3149dfa045f5
$(PKG)_SUBDIR   := fdk-aac-0.1.2
$(PKG)_FILE     := libfdk-aac-0.1.2.tar.bz2
$(PKG)_URL      := http://svn.vizrt.internal/svn/3rdpartyarchives/fdk-aac/libfdk-aac-0.1.2.tar.bz2
$(PKG)_DEPS     := gcc

define $(PKG)_UPDATE
    echo 'TODO: write update script for $(PKG).' >&2;
    echo $($(PKG)_VERSION)
endef

define $(PKG)_BUILD
    cd '$(1)' && ./configure \
        $(MXE_CONFIGURE_OPTS)
    $(MAKE) -C '$(1)' -j '$(JOBS)'
    $(MAKE) -C '$(1)' -j '$(JOBS)' install
endef

