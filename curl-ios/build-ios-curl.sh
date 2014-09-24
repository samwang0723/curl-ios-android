#!/bin/bash

set -e

VERSION="7.36.0"
OPENSSL_VERSION="1.0.1g"

if [ ! -e curl-${VERSION}.tar.gz ]; then
	echo "Downloading curl-${VERSION}.tar.gz"
    curl -O http://curl.haxx.se/download/curl-${VERSION}.tar.gz
else
	echo "Using curl-${VERSION}.tar.gz"
fi

SDKVERSION="8.0"
MIN_VERSION="7.0"

ARCHS="i386 x86_64 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`
CURRENTPATH=`pwd`

OPENSSL="${CURRENTPATH}/../openssl-ios/openssl-${OPENSSL_VERSION}-universal"

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

rm -rf curl-${VERSION}
rm -rf curl-${VERSION}-*
tar -zxvf curl-${VERSION}.tar.gz
pushd .
cd curl-${VERSION}
cp ../tool_hugehelp.h src
cp ../tool_operate.c src

for ARCH in ${ARCHS}
do
  if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
  then
      PLATFORM="iPhoneSimulator"
      HOST="${ARCH}-apple-darwin"
  else
      PLATFORM="iPhoneOS"
      if [[ "${ARCH}" == "arm64" ]];
	  then
          HOST="aarch64-apple-darwin"	
      else
          HOST="${ARCH}-apple-darwin"
      fi
  fi

  echo "Building libcurl for ${PLATFORM} ${SDKVERSION} ${ARCH} ${HOST}"
  echo "Please stand by...path=${CURRENTPATH}"

  export IPHONEOS_DEPLOYMENT_TARGET="8.0" 
  export CC="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
  export CPPFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk -I${OPENSSL}/include"
  export LDFLAGS="-arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk -L${OPENSSL}/lib"

  mkdir "curl-${VERSION}-${ARCH}"
  ./configure -prefix=${CURRENTPATH}/curl-${VERSION}-${ARCH} --host=${HOST} --with-zlib --disable-shared --enable-static --disable-ipv6 --disable-manual --disable-verbose --with-ssl
  make -j `sysctl -n hw.logicalcpu_max`
  make install
  make clean
done

popd

mkdir -p curl-${VERSION}-universal/include

cp -r ${CURRENTPATH}/curl-${VERSION}-armv7/include/curl curl-${VERSION}-universal/include

mkdir -p curl-${VERSION}-universal/lib

lipo \
	"${CURRENTPATH}/curl-${VERSION}-armv7/lib/libcurl.a" \
	"${CURRENTPATH}/curl-${VERSION}-armv7s/lib/libcurl.a" \
	"${CURRENTPATH}/curl-${VERSION}-arm64/lib/libcurl.a" \
	"${CURRENTPATH}/curl-${VERSION}-i386/lib/libcurl.a" \
	"${CURRENTPATH}/curl-${VERSION}-x86_64/lib/libcurl.a" \
	-create -output curl-${VERSION}-universal/lib/libcurl.a
