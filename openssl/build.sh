#!/bin/bash

#  Automatic build script for libssl and libcrypto
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here                                                     #
#                                                                         #
VERSION="1.1.1d"                                                          #
MIN_IOS_VERSION="8.0"                                                     #
#                                                                         #
###########################################################################
#                                                                         #
# Don't change anything under this line!                                  #
#                                                                         #
###########################################################################

set -e

OPENSSL_VERSION="openssl-${VERSION}"
CURRENTPATH=`pwd`
DEVELOPER=`xcode-select -print-path`

#configure options
OPENSSL_CONFIGURE_OPTIONS="-no-shared -no-tests \
                           -no-pic -no-idea -no-camellia \
                           -no-seed -no-bf -no-cast -no-rc2 -no-rc4 -no-rc5 \
                           -no-md2 -no-md4 -no-ssl3 \
                           -no-dsa -no-tls1 \
                           -no-rfc3779 -no-whirlpool -no-srp \
                           -no-mdc2 -no-engine -no-ui-console \
                           -no-comp -no-hw -no-srtp -fPIC"

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

build()
{
    ARCH=$1

    pushd . > /dev/null
    cd "${OPENSSL_VERSION}"

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi

    export $PLATFORM
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"
    export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"

    INSTALL_DIR="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    mkdir -p "${INSTALL_DIR}"
    
    BUILD_LOG="${INSTALL_DIR}/build-openssl-${VERSION}.log"
    CONFIG_LOG="${INSTALL_DIR}/config-openssl-${VERSION}.log"

    echo "Building ${OPENSSL_VERSION} || ${PLATFORM} ${ARCH}"

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        TARGET="darwin-i386-cc"
        if [[ $ARCH == "x86_64" ]]; then
            TARGET="darwin64-x86_64-cc"
        fi
        
        ./Configure no-asm ${TARGET} ${OPENSSL_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}" &> "${CONFIG_LOG}"
    else
        ./Configure iphoneos-cross DSO_LDFLAGS=-fembed-bitcode --prefix="${INSTALL_DIR}" ${OPENSSL_CONFIGURE_OPTIONS} --openssldir="${INSTALL_DIR}" &> "${CONFIG_LOG}"
    fi
    
    if [ $? != 0 ];
    then
        echo "Problem while configure - Please check ${CONFIG_LOG}"
        exit 1
    fi
    
    # add -isysroot to CC=
    sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${MIN_IOS_VERSION} !" "Makefile"

    perl configdata.pm --dump >> "${CONFIG_LOG}" 2>&1

    make -j $(sysctl -n hw.ncpu) >> "${BUILD_LOG}" 2>&1
    
    if [ $? != 0 ];
    then
        echo "Problem while make - Please check ${BUILD_LOG}"
        exit 1
    fi
    
    make install_sw >> "${BUILD_LOG}" 2>&1
    make clean >> "${BUILD_LOG}" 2>&1
    popd > /dev/null
}

packLibrary()
{
    LIBRARY=$1
    
    lipo \
        "${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/lib/lib${LIBRARY}.a" \
        "${CURRENTPATH}/bin/iPhoneSimulator-x86_64.sdk/lib/lib${LIBRARY}.a" \
        "${CURRENTPATH}/bin/iPhoneOS-armv7.sdk/lib/lib${LIBRARY}.a" \
        "${CURRENTPATH}/bin/iPhoneOS-armv7s.sdk/lib/lib${LIBRARY}.a" \
        "${CURRENTPATH}/bin/iPhoneOS-arm64.sdk/lib/lib${LIBRARY}.a" \
        "${CURRENTPATH}/bin/iPhoneOS-arm64e.sdk/lib/lib${LIBRARY}.a" \
        -create -output ${CURRENTPATH}/build/lib/lib${LIBRARY}.a
}

echo "Cleaning up"

rm -rf "${CURRENTPATH}/bin"
rm -rf "${CURRENTPATH}/build"

rm -rf "${OPENSSL_VERSION}"

mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/build/lib"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
    echo "Downloading ${OPENSSL_VERSION}.tar.gz"
    curl -LO https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
    echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

echo "Building OpenSSL ${VERSION} for iOS"
build "i386"
build "x86_64"
build "armv7"
build "armv7s"
build "arm64"
build "arm64e"

echo "  Copying headers and libraries"
cp -R ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/include/openssl ${CURRENTPATH}/build/include/

packLibrary "crypto"
packLibrary "ssl"

lipo -info ${CURRENTPATH}/build/lib/libssl.a
lipo -info ${CURRENTPATH}/build/lib/libcrypto.a

echo "Create Archive"
cd ${CURRENTPATH}/build
tar -czf ${CURRENTPATH}/openssl-ios.tar.gz *
cd ${CURRENTPATH}

echo "Cleaning up"
rm -rf "${CURRENTPATH}/bin"
rm -rf "${CURRENTPATH}/build"

rm -rf "${OPENSSL_VERSION}"
