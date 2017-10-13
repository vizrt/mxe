#!/bin/sh

set -e

if [ -z "${TARGET}" ]; then
    TARGET='x86_64-w64-mingw32.shared'
fi


DST=ffmpeg-2.8.4/packaging

if [ -d ${DST} ]; then
    rm -rf ${DST}
fi

mkdir ${DST}
mkdir ${DST}/bin
mkdir ${DST}/lib
mkdir ${DST}/include

cp usr/${TARGET}/bin/ffmpeg.exe ${DST}/bin/
cp usr/${TARGET}/bin/ffprobe.exe ${DST}/bin/
cp usr/${TARGET}/bin/ffplay.exe ${DST}/bin/
cp usr/${TARGET}/bin/*.lib ${DST}/lib/
cp ffmpeg-2.8.4/winconfig ${DST}/lib/. -r
cp usr/${TARGET}/bin/*.dll ${DST}/bin/
cp -r usr/${TARGET}/include/libavformat ${DST}/include/
cp -r usr/${TARGET}/include/libavcodec ${DST}/include/
cp -r usr/${TARGET}/include/libavdevice ${DST}/include/
cp -r usr/${TARGET}/include/libavfilter ${DST}/include/
cp -r usr/${TARGET}/include/libswresample ${DST}/include/
cp -r usr/${TARGET}/include/libavutil ${DST}/include/
cp -r usr/${TARGET}/include/libswscale ${DST}/include/
cp -r usr/${TARGET}/include/SDL ${DST}/include/
cp -r usr/${TARGET}/include/x264*.h ${DST}/include/
