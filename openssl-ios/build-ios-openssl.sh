#!/bin/bash


set -e

VERSION="1.0.1g"

if [ ! -e openssl-${VERSION}.tar.gz ]; then
	echo "Downloading openssl-${VERSION}.tar.gz"
    curl -O https://www.openssl.org/source/openssl-${VERSION}.tar.gz
else
	echo "Using openssl-${VERSION}.tar.gz"
fi

SDKVERSION="7.1"
MIN_VERSION="4.3"

ARCHS="i386 x86_64 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`
CURRENTPATH=`pwd`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

rm -rf openssl-${VERSION}
rm -rf openssl-${VERSION}-universal
tar -zxvf "openssl-${VERSION}.tar.gz"
pushd .
cd "openssl-${VERSION}"

for ARCH in ${ARCHS}
do
  if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
  then
      PLATFORM="iPhoneSimulator"
      if [[ "${ARCH}" == "x86_64" ]];
	  then
	    EXTRA="-DOPENSSL_NO_ASM"
	  fi
  else
      PLATFORM="iPhoneOS"
      EXTRA=""
  fi

  echo "Building libssl for ${PLATFORM} ${SDKVERSION} ${ARCH} ${EXTRA}"
  echo "Please stand by..."

  export GCC="${DEVELOPER}/usr/bin/gcc"
  export CFLAGS="-arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk"
  export LDFLAGS="-arch ${ARCH}"

  echo "Configure libssl for ${PLATFORM} ${SDKVERSION} ${ARCH}"
  ./Configure "BSD-generic32" --openssldir="/tmp/openssl-${VERSION}-${ARCH}" ${EXTRA}
  perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
  perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH} -miphoneos-version-min=${MIN_VERSION} ${EXTRA} |g" Makefile
  perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk ${EXTRA} |g" Makefile
  echo "Make libssl for ${PLATFORM} ${SDKVERSION} ${ARCH}"
  
  make
  make install
  make clean
done

popd

mkdir -p openssl-${VERSION}-universal/include
cp -r /tmp/openssl-${VERSION}-armv7/include/openssl openssl-${VERSION}-universal/include/

mkdir -p openssl-${VERSION}-universal/lib
lipo \
	"/tmp/openssl-${VERSION}-armv7/lib/libcrypto.a" \
	"/tmp/openssl-${VERSION}-armv7s/lib/libcrypto.a" \
	"/tmp/openssl-${VERSION}-arm64/lib/libcrypto.a" \
	"/tmp/openssl-${VERSION}-i386/lib/libcrypto.a" \
	"/tmp/openssl-${VERSION}-x86_64/lib/libcrypto.a" \
	-create -output openssl-${VERSION}-universal/lib/libcrypto.a
lipo \
	"/tmp/openssl-${VERSION}-armv7/lib/libssl.a" \
	"/tmp/openssl-${VERSION}-armv7s/lib/libssl.a" \
	"/tmp/openssl-${VERSION}-arm64/lib/libssl.a" \
	"/tmp/openssl-${VERSION}-i386/lib/libssl.a" \
	"/tmp/openssl-${VERSION}-x86_64/lib/libssl.a" \
	-create -output openssl-${VERSION}-universal/lib/libssl.a

rm -rf "/tmp/openssl-${VERSION}-*"
