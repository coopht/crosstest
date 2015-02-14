#!/bin/bash

#set -x

TARGET_ARCH=arm
TARGET=arm-v7a-linux-gnueabi
TOP=`pwd`

SRC=$TOP/src
BUILD=$TOP/build
LOGS=$BUILD/logs
INSTALL=$TOP/crosstest
ROOTFS=$INSTALL/rootfs
JOBS=-j4

SRC_QEMU=$SRC/qemu
SRC_LINUX=$SRC/linux-stable
SRC_BUSYBOX=$SRC/busybox-1.23.1
SRC_BASH=$SRC/bash-4.3.30
SRC_OPENSSL=$SRC/openssl-1.0.2
SRC_OPENSSH=$SRC/openssh-6.7p1
SRC_ZLIB=$SRC/zlib-1.2.8

QEMU_TARGETS='aarch64-softmmu,arm-softmmu,aarch64-linux-user,arm-linux-user'

TOOLCHAIN=${TOOLCHAIN}

CROSS_CC=${TOOLCHAIN}gcc
CROSS_CXX=${TOOLCHAIN}g++
CROSS_NM=${TOOLCHAIN}nm
CROSS_AR=${TOOLCHAIN}ar
CROSS_RANLIB=${TOOLCHAIN}ranlib
CROSS_LD=${TOOLCHAIN}ld
CROSS_STRIP=${TOOLCHAIN}strip

CONFIGS=$TOP/configs/

is_ok ()
{
   if [ $? -ne 0 ]; then
       echo Failed
       exit 1
   fi
   echo OK
}

initialize()
{
    LOG_INIT=$LOGS/init
    if [ -d $BUILD ] ; then
	rm -rfv $BUILD > $LOG_INIT 2>&1
    fi

    mkdir -pv $LOGS
    mkdir -pv $INSTALL > $LOG_INIT 2>&1
}

build_qemu()
{
    BUILD_QEMU=$BUILD/`basename $SRC_QEMU`
    LOG_QEMU=$LOGS/`basename $SRC_QEMU`
    mkdir -pv $BUILD_QEMU > $LOG_INIT 2>&1
    cd $BUILD_QEMU

    echo "Configure `basename $SRC_QEMU`"
    $SRC_QEMU/configure --prefix=$INSTALL --target-list=$QEMU_TARGETS >> $LOG_QEMU 2>&1
    is_ok

    echo "Build `basename $SRC_QEMU`"
    make $JOBS >> $LOG_QEMU 2>&1
    is_ok

    echo "Install `basename $SRC_QEMU`"
    make $JOBS install >> $LOG_QEMU 2>&1
    is_ok
    cd $TOP
}

build_linux()
{
    BUILD_LINUX=$BUILD/`basename $SRC_LINUX`
    LOG_LINUX=$LOGS/linux

    if [ -d $BUILD_LINUX ]; then
	rm -rfv $BUILD_LINUX > $LOG_LINUX 2>&1
    fi

    echo "Prepare `basename $SRC_LINUX`"
    cp -prv $SRC_LINUX $BUILD/ > $LOG_LINUX 2>&1
    is_ok

    cd $BUILD_LINUX
    echo "Configure `basename $SRC_LINUX`"
    cp -v $CONFIGS/.config_working_linux .config >> $LOG_LINUX 2>&1
    is_ok

    echo "Build `basename $SRC_LINUX`"
    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make $JOBS >> $LOG_LINUX 2>&1
    is_ok

    echo "Install `basename $SRC_LINUX`"
    mkdir -pv $INSTALL/linux >> $LOG_LINUX 2>&1
    cp -v ./arch/arm/boot/zImage $INSTALL/linux/ >> $LOG_LINUX 2>&1
    cp -v ./arch/arm/boot/dts/vexpress-v2p-ca15_a7.dtb $INSTALL/linux/ >> $LOG_LINUX 2>&1
    is_ok

    cd $TOP
}

build_busybox()
{
    BUILD_BUSYBOX=$BUILD/`basename $SRC_BUSYBOX`
    LOG_BUSYBOX=$LOGS/`basename $SRC_BUSYBOX`

    if [ -d $BUILD_BUSYBOX ]; then
	rm -rfv $BUILD_BUSYBOX > $LOG_BUSYBOX 2>&1
    fi

    cp -prv $SRC_BUSYBOX $BUILD/ > $LOG_BUSYBOX 2>&1

    cd $BUILD_BUSYBOX

    echo "Configure `basename $SRC_BUSYBOX`"
    cp -v $CONFIGS/.config_working_busybox .config >> $LOG_BUSYBOX 2>&1
    is_ok

    echo "Build `basename $SRC_BUSYBOX`"
    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make oldconfig >> $LOG_BUSYBOX 2>&1
    is_ok
    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make $JOBS install >> $LOG_BUSYBOX 2>&1
    is_ok

    cp -prv _install/* $ROOTFS/  >> $LOG_BUSYBOX 2>&1
    is_ok

    cd $TOP
}

prepare_rootfs()
{
    LOG_ROOTFS=$LOGS/rootfs
    if [ -d $ROOTFS ]; then
	rm -rfv $ROOTFS > $LOG_ROOTFS 2>&1
    fi

    echo "Prepare Rootfs"
    cp -prv $CONFIGS/rootfs.template $ROOTFS > $LOG_ROOTFS 2>&1
    is_ok

    mkdir -pv $ROOTFS/{proc,srv,sys,dev,var} >> $LOG_ROOTFS 2>&1
    is_ok

    install -dv -m 1777 $ROOTFS/tmp $ROOTFS/var/tmp >> $LOG_ROOTFS 2>&1
    is_ok
}

build_bash()
{
    BUILD_BASH=$BUILD/`basename $SRC_BASH`
    LOG_BASH=$LOGS/`basename $SRC_BASH`
    if [ -d $BUILD_BASH ]; then
	rm -rfv $BUILD_BASH > $LOG_BASH 2>&1
    fi

    mkdir -pv $BUILD_BASH > $LOG_BASH 2>&1

    cd $BUILD_BASH
    echo "Configure `basename $SRC_BASH`"
    CC=$CROSS_CC \
      $SRC_BASH/configure --prefix=$ROOTFS --host=$TARGET >> $LOG_BASH 2>&1
    is_ok

    echo "Build `basename $SRC_BASH`"
    make $JOBS >> $LOG_BASH 2>&1
    is_ok

    echo "Install `basename $SRC_BASH`"
    make install >> $LOG_BASH 2>&1
    is_ok

    cd $TOP
}

build_openssl()
{
    BUILD_OPENSSL=$BUILD/`basename $SRC_OPENSSL`
    LOG_OPENSSL=$LOGS/`basename $SRC_OPENSSL`
    if [ -d $BUILD_OPENSSL ]; then
	rm -rfv $BUILD_OPENSSL > $LOG_OPENSSL 2>&1
    fi

    cp -prv $SRC_OPENSSL $BUILD/ > $LOG_OPENSSL 2>&1

    cd $BUILD_OPENSSL

    echo "Configure `basename $SRC_OPENSSL`"
    CC=$CROSS_CC \
      RANLIB=$CROSS_RANLIB \
      AR=$CROSS_AR \
      $SRC_OPENSSL/Configure linux-armv4 shared --prefix=$ROOTFS >> $LOG_OPENSSL 2>&1
    is_ok

    echo "Build `basename $SRC_OPENSSL`"
    make >> $LOG_OPENSSL 2>&1
    is_ok

    echo "Install `basename $SRC_OPENSSL`"
    make install >> $LOG_OPENSSL 2>&1
    is_ok

    cd $TOP
}

build_openssh()
{
    BUILD_OPENSSH=$BUILD/`basename $SRC_OPENSSH`
    LOG_OPENSSH=$LOGS/`basename $SRC_OPENSSH`
    if [ -d $BUILD_OPENSSH ]; then
	rm -rfv $BUILD_OPENSSH > $LOG_OPENSSH 2>&1
    fi

    mkdir -pv $BUILD_OPENSSH > $LOG_OPENSSH 2>&1

    cd $BUILD_OPENSSH

    echo "Configure `basename $SRC_OPENSSH`"
    CC=$CROSS_CC \
      AR=$CROSS_AR \
      RANLIB=$CROSS_RANLIB \
      STRIP=$CROSS_STRIP \
      $SRC_OPENSSH/configure --prefix=$ROOTFS --host=$TARGET --with-zlib=$ROOTFS --disable-strip >> $LOG_OPENSSH 2>&1
    is_ok

    echo "Build `basename $SRC_OPENSSH`"
    make $JOBS >> $LOG_OPENSSH 2>&1
    is_ok

    echo "Install `basename $SRC_OPENSSH`"
    make -k install >> $LOG_OPENSSH 2>&1

    cd $TOP

}

build_zlib()
{
    BUILD_ZLIB=$BUILD/`basename $SRC_ZLIB`
    LOG_ZLIB=$LOGS/`basename $SRC_ZLIB`
    if [ -d $BUILD_ZLIB ]; then
	rm -rfv $BUILD_ZLIB > $LOG_ZLIB 2>&1
    fi

    cp -prv $SRC_ZLIB $BUILD/ > $LOG_ZLIB 2>&1

    cd $BUILD_ZLIB

    echo "Configure `basename $SRC_ZLIB`"
    CC=$CROSS_CC \
      AR=$CROSS_AR \
      $SRC_ZLIB/configure --prefix=$ROOTFS >> $LOG_ZLIB 2>&1
    is_ok

    echo "Build `basename $SRC_ZLIB`"
    make $JOBS >> $LOG_ZLIB 2>&1
    is_ok

    echo "Install `basename $SRC_ZLIB`"
    make install >> $LOG_ZLIB 2>&1
    is_ok

    cd $TOP

}

initialize
build_qemu
build_linux
prepare_rootfs
build_busybox
build_bash
build_zlib
build_openssl
build_openssh
