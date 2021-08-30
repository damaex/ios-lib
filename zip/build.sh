#!/bin/bash

#  Automatic build script for libzip
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here													  #
#                                                                         #
VERSION="1.8.0"												              #
MIN_IOS_VERSION="9.0"                                                     #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################

#configure options
ZIP_CONFIGURE_OPTIONS="-DBUILD_SHARED_LIBS=OFF \
                        -DBUILD_TOOLS=OFF \
                        -DBUILD_DOC=OFF \
                        -DBUILD_REGRESS=OFF \
                        -DBUILD_EXAMPLES=OFF"


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
if [ ! -e zip-${VERSION}.tar.gz ]; then
    echo "Downloading zip-${VERSION}.tar.gz"
    curl -O -L -s https://libzip.org/download/libzip-${VERSION}.tar.gz
else
    echo "Using opus-${VERSION}.tar.gz"
fi

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/build/lib"

tar zxf libzip-${VERSION}.tar.gz -C "${CURRENTPATH}/src"
cd "${CURRENTPATH}/src/libzip-${VERSION}"


for ARCH in ${ARCHS}
do
    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
    then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi

    case "${ARCH}" in
    "i386")
        BUILD_PLATFORM="SIMULATOR"
        ;;
    "x86_64")
        BUILD_PLATFORM="SIMULATOR64"
        ;;
    "armv7")
        BUILD_PLATFORM="OS"
        ;;
    "armv7s")
        BUILD_PLATFORM="OS"
        ;;
    "arm64")
        BUILD_PLATFORM="OS64"
        ;;
    "arm64e")
        BUILD_PLATFORM="OS64"
        ;;
    esac

    echo "Building zip-${VERSION} for ${PLATFORM}  ${ARCH}"
    echo "Please stand by..."

    mkdir -p "${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    LOG="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk/build-zip-${VERSION}.log"

    set +e
    INSTALL_DIR="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    mkdir "build-${ARCH}"
    cd "build-${ARCH}"
    cmake .. -DCMAKE_TOOLCHAIN_FILE=${CURRENTPATH}/../toolchain/ios.toolchain.cmake -DCMAKE_INSTALL_PREFIX:PATH="${INSTALL_DIR}" -DPLATFORM=${BUILD_PLATFORM} -DARCHS=${ARCH} ${ZIP_CONFIGURE_OPTIONS} -DCMAKE_PREFIX_PATH="${CURRENTPATH}/../openssl/bin/${PLATFORM}-${ARCH}.sdk" > "${LOG}" 2>&1

    if [ $? != 0 ];
    then
        echo "Problem while configure - Please check ${LOG}"
        exit 1
    fi

    cmake --build . --parallel $(sysctl -n hw.ncpu) --config Release --target install  >> "${LOG}" 2>&1

    if [ $? != 0 ];
    then
        echo "Problem while building - Please check ${LOG}"
        exit 1
    fi

    cd ..
    set -e
done

echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/lib/libzip.a ${CURRENTPATH}/bin/iPhoneSimulator-x86_64.sdk/lib/libzip.a  ${CURRENTPATH}/bin/iPhoneOS-armv7.sdk/lib/libzip.a ${CURRENTPATH}/bin/iPhoneOS-armv7s.sdk/lib/libzip.a ${CURRENTPATH}/bin/iPhoneOS-arm64.sdk/lib/libzip.a ${CURRENTPATH}/bin/iPhoneOS-arm64e.sdk/lib/libzip.a -output ${CURRENTPATH}/build/lib/libzip.a

mkdir -p ${CURRENTPATH}/build/include
cp -R ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/include ${CURRENTPATH}/build/include/
echo "Building done."
echo "Cleaning up..."
rm -rf ${CURRENTPATH}/src/zip-${VERSION}
echo "Done."

lipo -info ${CURRENTPATH}/build/lib/libzip.a

cd ${CURRENTPATH}/build
tar -czf ${CURRENTPATH}/zip-ios.tar.gz *

cd ${CURRENTPATH}
