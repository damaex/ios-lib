#!/bin/bash

mkdir -p "build"

cd openssl
./build.sh
if [ $? -ne 0 ]; then
	echo "Error: Build openssl"
	exit 1
fi
cd ..

mv openssl/openssl-ios.tar.gz build/

cd boringssl
./build.sh
if [ $? -ne 0 ]; then
	echo "Error: Build boringssl"
	exit 1
fi
cd ..

mv boringssl/boringssl-ios.tar.gz build/

cd opus
./build.sh
if [ $? -ne 0 ]; then
    echo "Error: Build opus"
    exit 1
fi
cd ..

mv opus/opus-ios.tar.gz build/

cd zip
./build.sh
if [ $? -ne 0 ]; then
    echo "Error: Build zip"
    exit 1
fi
cd ..

mv zip/zip-ios.tar.gz build/

cd png
./build.sh
    if [ $? -ne 0 ]; then
    echo "Error: Build png"
exit 1
fi
cd ..

mv png/png-ios.tar.gz build/

cd haru
./build.sh
    if [ $? -ne 0 ]; then
    echo "Error: Build haru"
exit 1
fi
cd ..

mv haru/haru-ios.tar.gz build/
