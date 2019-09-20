#!/usr/bin/env bash

mkdir -p "build"

cd openssl
bash build.sh verbose
if [ $? -ne 0 ]; then
	echo "Error: Build openssl"
	exit 1
fi
cd ..

mv openssl/openssl-ios.tar.gz build/

cd opus
bash build.sh
if [ $? -ne 0 ]; then
echo "Error: Build opus"
exit 1
fi
cd ..

mv opus/opus-ios.tar.gz build/

cd zip
bash build.sh
if [ $? -ne 0 ]; then
echo "Error: Build zip"
exit 1
fi
cd ..

mv png/zip-ios.tar.gz build/

cd png
bash build.sh
if [ $? -ne 0 ]; then
echo "Error: Build png"
exit 1
fi
cd ..

mv png/png-ios.tar.gz build/

cd haru
bash build.sh
if [ $? -ne 0 ]; then
echo "Error: Build haru"
exit 1
fi
cd ..

mv png/haru-ios.tar.gz build/
