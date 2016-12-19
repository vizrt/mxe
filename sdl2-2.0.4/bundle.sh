#!/bin/sh

set -e

if [ -z "${TARGET}" ]; then
    TARGET='x86_64-w64-mingw32.shared'
fi


DST=sdl2-2.0.4/packaging

if [ -d ${DST} ]; then
    rm -rf ${DST}
fi

mkdir ${DST}
mkdir ${DST}/bin
mkdir ${DST}/lib
mkdir ${DST}/include

cp usr/${TARGET}/lib/SDL2.lib ${DST}/lib/
cp usr/${TARGET}/bin/SDL2.dll ${DST}/bin/
cp -r usr/${TARGET}/include/SDL2 ${DST}/include/

