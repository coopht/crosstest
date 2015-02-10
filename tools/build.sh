#!/bin/bash

set -x

TARGET_ARCH=arm
TARGET=arm_v7a-linux-gnueabi
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

QEMU_TARGETS='aarch64-softmmu,arm-softmmu,aarch64-linux-user,arm-linux-user'

TOOLCHAIN=${TOOLCHAIN}

CROSS_CC=${TOOLCHAIN}gcc
CROSS_CXX=${TOOLCHAIN}g++
CROSS_NM=${TOOLCHAIN}nm
CROSS_AR=${TOOLCHAIN}ar
CROSS_RANLIB=${TOOLCHAIN}ranlib
CROSS_LD=${TOOLCHAIN}ld

CONFIGS=$TOP/configs/

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
    $SRC_QEMU/configure --prefix=$INSTALL --target-list=$QEMU_TARGETS >> $LOG_QEMU 2>&1
    make $JOBS >> $LOG_QEMU 2>&1
    make $JOBS install >> $LOG_QEMU 2>&1
    cd $TOP
}

build_linux()
{
    BUILD_LINUX=$BUILD/`basename $SRC_LINUX`
    LOG_LINUX=$LOGS/linux

    if [ -d $BUILD_LINUX ]; then
	rm -rfv $BUILD_LINUX > $LOG_LINUX 2>&1
    fi

    cp -prv $SRC_LINUX $BUILD/ > $LOG_LINUX 2>&1

    cd $BUILD_LINUX
    cp -v $CONFIGS/.config_working_linux .config >> $LOG_LINUX 2>&1
    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make -j8 >> $LOG_LINUX 2>&1

    mkdir -pv $INSTALL/linux >> $LOG_LINUX 2>&1
    cp -v ./arch/arm/boot/zImage $INSTALL/linux/ >> $LOG_LINUX 2>&1
    cp -v ./arch/arm/boot/dts/vexpress-v2p-ca15_a7.dtb $INSTALL/linux/ >> $LOG_LINUX 2>&1
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

    cp -v $CONFIGS/.config_working_busybox .config >> $LOG_BUSYBOX 2>&1

    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make oldconfig >> $LOG_BUSYBOX 2>&1
    ARCH=$TARGET_ARCH CROSS_COMPILE=$TOOLCHAIN make -j4 install >> $LOG_BUSYBOX 2>&1

    cp -prv _install/* $ROOTFS/

    cd $TOP
}

prepare_rootfs()
{
    LOG_ROOTFS=$LOGS/rootfs
    if [ -d $ROOTFS ]; then
	rm -rfv $ROOTFS > $LOG_ROOTFS 2>&1
    fi

    cp -prv $CONFIGS/rootfs.template $ROOTFS > $LOG_ROOTFS 2>&1
    mkdir -pv $ROOTFS/{proc,srv,sys,dev,var} >> $LOG_ROOTFS 2>&1
    install -dv -m 1777 $ROOTFS/tmp $ROOTFS/var/tmp >> $LOG_ROOTFS 2>&1
}

initialize
build_qemu
build_linux
prepare_rootfs
build_busybox
