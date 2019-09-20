#!/usr/bin/env bash

#  Automatic build script for libopus
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here													  #
#                                                                         #
VERSION="1.3.1"												              #
MIN_IOS_VERSION="8.0"                                                     #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################

#configure options
OPUS_CONFIGURE_OPTIONS="--enable-float-approx \
                        --disable-shared \
                        --enable-static \
                        --with-pic \
                        --disable-extra-programs \
                        --disable-doc \
                        --enable-asm"


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
if [ ! -e opus-${VERSION}.tar.gz ]; then
    echo "Downloading opus-${VERSION}.tar.gz"
    curl -O https://archive.mozilla.org/pub/opus/opus-${VERSION}.tar.gz
else
    echo "Using opus-${VERSION}.tar.gz"
fi

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/build/lib"

tar zxf opus-${VERSION}.tar.gz -C "${CURRENTPATH}/src"
cd "${CURRENTPATH}/src/opus-${VERSION}"


for ARCH in ${ARCHS}
do
    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
    then
        PLATFORM="iPhoneSimulator"
        if [ "${ARCH}" == "x86_64" ]
        then
            HOST=x86_64-apple-darwin
        else
            HOST=i386-apple-darwin
        fi
    else
        PLATFORM="iPhoneOS"
        HOST=arm-apple-darwin
    fi

    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"

    echo "Building opus-${VERSION} for ${PLATFORM}  ${ARCH}"
    echo "Please stand by..."

    mkdir -p "${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    LOG="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk/build-opus-${VERSION}.log"

    XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
    export CC="xcrun -sdk ${XCRUN_SDK} clang -mios-version-min=${MIN_IOS_VERSION} -arch ${ARCH}"
    CFLAGS="-arch ${ARCH} -D__OPTIMIZE__ -fembed-bitcode"

    set +e
    INSTALL_DIR="${CURRENTPATH}/bin/${PLATFORM}-${ARCH}.sdk"
    if [[ "$VERSION" =~ 1.0.0. ]]; then
        ./configure BSD-generic32 ${OPUS_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" > "${LOG}" 2>&1
#elif [ "${ARCH}" == "x86_64" ]; then
#       ./Configure darwin64-x86_64-cc ${OPENSSL_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" --openssldir="${INSTALL_DIR}" > "${LOG}" 2>&1
    else
./configure --host=${HOST} ${OPUS_CONFIGURE_OPTIONS} --prefix="${INSTALL_DIR}" CFLAGS="${CFLAGS}" > "${LOG}" 2>&1
    fi

    if [ $? != 0 ];
    then
        echo "Problem while configure - Please check ${LOG}"
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
    make install >> "${LOG}" 2>&1
    make clean >> "${LOG}" 2>&1
done

echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/lib/libopus.a ${CURRENTPATH}/bin/iPhoneSimulator-x86_64.sdk/lib/libopus.a  ${CURRENTPATH}/bin/iPhoneOS-armv7.sdk/lib/libopus.a ${CURRENTPATH}/bin/iPhoneOS-armv7s.sdk/lib/libopus.a ${CURRENTPATH}/bin/iPhoneOS-arm64.sdk/lib/libopus.a ${CURRENTPATH}/bin/iPhoneOS-arm64e.sdk/lib/libopus.a -output ${CURRENTPATH}/build/lib/libopus.a

mkdir -p ${CURRENTPATH}/build/include
cp -R ${CURRENTPATH}/bin/iPhoneSimulator-i386.sdk/include/opus ${CURRENTPATH}/build/include/
echo "Building done."
echo "Cleaning up..."
rm -rf ${CURRENTPATH}/src/opus-${VERSION}
echo "Done."

lipo -info ${CURRENTPATH}/build/lib/libopus.a

cd ${CURRENTPATH}/build
tar -czf ${CURRENTPATH}/opus-ios.tar.gz *

cd ${CURRENTPATH}
