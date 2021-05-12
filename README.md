# ios-lib
![Build Status](https://github.com/damaex/ios-lib/actions/workflows/build.yml/badge.svg)

prebuild some libs for iOS

architectures: `i386`, `x86_64`, `armv7`, `armv7s`, `arm64`, `arm64e`

## libraries

| library | version |
| ------- | ------- |
| openssl | 1.1.1k  |
| opus    | 1.3.1   |
| libzip  | 1.7.3   |
| libpng  | 1.6.37  |
| libharu | 2.3.0   |

## requirements
- XCode
- cmake

## build
```bash
git submodule update --init --recursive
./build.sh
```
