#!/usr/bin/env bash

#  Automatic build script for libssl and libcrypto
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here													  #
#                                                                         #
VERSION="1.1.1c"												          #
MIN_IOS_VERSION="8.0"                                                     #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################

#configure options
OPENSSL_CONFIGURE_OPTIONS="no-pic no-idea no-camellia \
                            no-seed no-bf no-cast no-rc2 no-rc4 no-rc5 no-md2 \
                            no-md4 no-ssl3 \
                            no-dsa no-tls1 \
                            no-rfc3779 no-whirlpool no-srp \
                            no-mdc2 no-engine \
                            no-comp no-hw no-srtp -fPIC"


CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64 arm64e"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
    echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
    echo "run"
    echo "sudo xcode-select -switch <xcode path>"
    echo "for default installation:"
    echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

case $DEVELOPER in
    *\ * )
    echo "Your Xcode path contains whitespaces, which is not supported."
    exit 1
    ;;
esac

case $CURRENTPATH in
    *\ * )
    echo "Your path contains whitespaces, which is not supported by 'make install'."
    exit 1
    ;;
esac

set -e
if [ ! -e openssl-${VERSION}.tar.gz ]; then
    echo "Downloading openssl-${VERSION}.tar.gz"
    curl -O https://www.openssl.org/source/openssl-${VERSION}.tar.gz
else
    echo "Using openssl-${VERSION}.tar.gz"
fi

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/build/lib"

tar zxf openssl-${VERSION}.tar.gz -C "${CURRENTPATH}/src"
cd "${CURRENTPATH}/src/openssl-${VERSION}"


for ARCH in ${ARCHS}
do
    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
    then
        PLATFORM="iPhoneSimulator"
    else
        sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
        PLATFORM="iPhoneOS"
    fi

    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"

    echo "Building openssl-${VERSION} for ${PLATFORM}  ${ARCH}"
    echo "Please stand by..."

    mkdir -p "${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    LOG="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk/build-openssl-${VERSION}.log"

    export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -mios-version-min=${MIN_IOS_VERSION} -arch ${ARCH}"

    set +e
    INSTALL_DIR="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    if [[ "$VERSION" =~ 1.0.0. ]]; then
        ./Configure BSD-generic32 ${OPENSSL_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}" > "${LOG}" 2>&1
#elif [ "${ARCH}" == "x86_64" ]; then
#       ./Configure darwin64-x86_64-cc ${OPENSSL_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}" > "${LOG}" 2>&1
    else
        ./Configure iphoneos-cross ${OPENSSL_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}" > "${LOG}" 2>&1
    fi

    if [ $? != 0 ];
    then
        echo "Problem while configure - Please check ${LOG}"
		echo "$(<${LOG})"
		
        exit 1
    fi

    # add -isysroot to CC=
    sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${MIN_IOS_VERSION} !" "Makefile"

    if [ "$1" == "verbose" ];
    then
        make -j$(sysctl -n hw.ncpu)
    else
        make -j$(sysctl -n hw.ncpu) >> "${LOG}" 2>&1
    fi

    if [ $? != 0 ];
    then
        echo "Problem while make - Please check ${LOG}"
        exit 1
    fi

    set -e
    make install_sw >> "${LOG}" 2>&1
    make clean >> "${LOG}" 2>&1
done

echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/lib/libssl.a ${CURRENTPATH}/bin/iPhoneSimulator-x86_64.sdk/lib/libssl.a  ${CURRENTPATH}/bin/iPhoneOS-armv7.sdk/lib/libssl.a ${CURRENTPATH}/bin/iPhoneOS-armv7s.sdk/lib/libssl.a ${CURRENTPATH}/bin/iPhoneOS-arm64.sdk/lib/libssl.a ${CURRENTPATH}/bin/iPhoneOS-arm64e.sdk/lib/libssl.a -output ${CURRENTPATH}/build/lib/libssl.a
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/lib/libcrypto.a ${CURRENTPATH}/bin/iPhoneSimulator-x86_64.sdk/lib/libcrypto.a ${CURRENTPATH}/bin/iPhoneOS-armv7.sdk/lib/libcrypto.a ${CURRENTPATH}/bin/iPhoneOS-armv7s.sdk/lib/libcrypto.a ${CURRENTPATH}/bin/iPhoneOS-arm64.sdk/lib/libcrypto.a ${CURRENTPATH}/bin/iPhoneOS-arm64e.sdk/lib/libcrypto.a -output ${CURRENTPATH}/build/lib/libcrypto.a

mkdir -p ${CURRENTPATH}/build/include
cp -R ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/include/openssl ${CURRENTPATH}/build/include/
echo "Building done."
echo "Cleaning up..."
rm -rf ${CURRENTPATH}/src/openssl-${VERSION}
echo "Done."

lipo -info ${CURRENTPATH}/build/lib/libssl.a
lipo -info ${CURRENTPATH}/build/lib/libcrypto.a

cd ${CURRENTPATH}/build
tar -czf ${CURRENTPATH}/openssl-ios.tar.gz *

cd ${CURRENTPATH}
