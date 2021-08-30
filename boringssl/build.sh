#!/bin/bash

#  Automatic build script for boringssl
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here													  #
#                                                                         #
GIT_HASH="c6d3fd1d0972d17b2b115f6b7482b62e50406f56"												              #
MIN_IOS_VERSION="9.0"                                                     #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################

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
#git clone and hash checkout
if [ ! -d boringssl ]
then
    git clone https://github.com/google/boringssl.git
    cd boringssl
else
    cd boringssl
    git pull https://github.com/google/boringssl.git
fi

git checkout ${GIT_HASH}
cd ..

#create work folders
SRC_PATH="${CURRENTPATH}/boringssl"
BINARY_PATH="${CURRENTPATH}/bin"
BUILD_BASE_PATH="${CURRENTPATH}/build"

mkdir -p "${BINARY_PATH}"
mkdir -p "${BUILD_BASE_PATH}"

#arch loop
for ARCH in ${ARCHS}
do
    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
    then
        PLATFORM="iphonesimulator"
        EXTRA_CONFIGURE_OPTIONS="-DOPENSSL_NO_ASM=1"
    else
        PLATFORM="iphoneos"
        EXTRA_CONFIGURE_OPTIONS=""
    fi

    echo "Building boringssl for ${PLATFORM}  ${ARCH}"
    echo "Please stand by..."

    set +e

    mkdir -p "${BUILD_BASE_PATH}/${PLATFORM}-${ARCH}.sdk"
    LOG="${BUILD_BASE_PATH}/build-boringssl-${PLATFORM}-${ARCH}.log"

    INSTALL_DIR="${BINARY_PATH}/${PLATFORM}-${ARCH}.sdk"
    cd "${BUILD_BASE_PATH}/${PLATFORM}-${ARCH}.sdk"
    cmake ${SRC_PATH} \
        -DCMAKE_OSX_SYSROOT=${PLATFORM} \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_IOS_VERSION} \
        -DCMAKE_INSTALL_PREFIX:PATH="${INSTALL_DIR}" \
        -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
        ${EXTRA_CONFIGURE_OPTIONS} \
        > "${LOG}" 2>&1

    if [ $? != 0 ];
    then
        echo "Problem while configure - Please check ${LOG}"
        exit 1
    fi

    cmake --build . --parallel $(sysctl -n hw.ncpu) --config Release >> "${LOG}" 2>&1

    if [ $? != 0 ];
    then
        echo "Problem while building - Please check ${LOG}"
        exit 1
    fi

    cd ..
    set -e
done

echo "Build library..."
mkdir -p "${BINARY_PATH}/lib"
lipo -create ${BUILD_BASE_PATH}/iphonesimulator-i386.sdk/ssl/libssl.a \
    ${BUILD_BASE_PATH}/iphonesimulator-x86_64.sdk/ssl/libssl.a \
    ${BUILD_BASE_PATH}/iphoneos-armv7.sdk/ssl/libssl.a \
    ${BUILD_BASE_PATH}/iphoneos-armv7s.sdk/ssl/libssl.a \
    ${BUILD_BASE_PATH}/iphoneos-arm64.sdk/ssl/libssl.a \
    ${BUILD_BASE_PATH}/iphoneos-arm64e.sdk/ssl/libssl.a \
    -output ${BINARY_PATH}/lib/libssl.a

lipo -create ${BUILD_BASE_PATH}/iphonesimulator-i386.sdk/crypto/libcrypto.a \
    ${BUILD_BASE_PATH}/iphonesimulator-x86_64.sdk/crypto/libcrypto.a \
    ${BUILD_BASE_PATH}/iphoneos-armv7.sdk/crypto/libcrypto.a \
    ${BUILD_BASE_PATH}/iphoneos-armv7s.sdk/crypto/libcrypto.a \
    ${BUILD_BASE_PATH}/iphoneos-arm64.sdk/crypto/libcrypto.a \
    ${BUILD_BASE_PATH}/iphoneos-arm64e.sdk/crypto/libcrypto.a \
    -output ${BINARY_PATH}/lib/libcrypto.a

mkdir -p ${BINARY_PATH}/include
cp -R ${SRC_PATH}/include ${BINARY_PATH}/include/
echo "Building done."

lipo -info ${BINARY_PATH}/lib/libssl.a
lipo -info ${BINARY_PATH}/lib/libcrypto.a

cd ${BINARY_PATH}
tar -czf ${CURRENTPATH}/boringssl-ios.tar.gz *

echo "Cleaning up..."
rm -rf ${SRC_PATH}
rm -rf ${BINARY_PATH}
rm -rf ${BUILD_BASE_PATH}
echo "Done."

cd ${CURRENTPATH}