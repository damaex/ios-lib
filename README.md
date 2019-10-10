# ios-lib
[![Build Status](https://travis-ci.org/damaex/ios-lib.svg?branch=master)](https://travis-ci.org/damaex/ios-lib)

prebuild some libs for iOS

architectures: `i386`, `x86_64`, `armv7`, `armv7s`, `arm64`, `arm64e`

## libraries

| library | version |
| ------- | ------- |
| openssl | 1.1.1d  |
| opus    | 1.3.1   |
| libzip  | 1.5.2   |
| libpng  | 1.6.37  |
| libharu | 2.3.0   |

## requirements
- XCode
- cmake
- wget

## build
```bash
git submodule update --init --recursive
./build.sh
```