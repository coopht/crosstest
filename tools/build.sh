#!/bin/bash
set -x

TARGET=arm_v7a-linux-gnueabi
TOP=`pwd`

SRC=$TOP/src
BUILD=$TOP/build
LOGS=$BUILD/logs
INSTALL=$TOP/crosstest
JOBS=-j4

SRC_QEMU=$SRC/qemu

QEMU_TARGETS='aarch64-softmmu,arm-softmmu,aarch64-linux-user,arm-linux-user'

initialize()
{
    LOG_INIT=$LOGS/init
    if [ -d $BUILD ] ; then
	rm -rfv $BUILD &> $LOG_INIT
    fi

    mkdir -pv $LOGS
    mkdir -pv $INSTALL &> $LOG_INIT
}

build_qemu ()
{
    BUILD_QEMU=$BUILD/`basename $SRC_QEMU`
    LOG_QEMU=$LOGS/`basename $SRC_QEMU`
    mkdir -pv $BUILD_QEMU &> $LOG_INIT
    cd $BUILD_QEMU
    $SRC_QEMU/configure --prefix=$INSTALL --target-list=$QEMU_TARGETS &> $LOG_QEMU
    make $JOBS &> $LOG_QEMU
    make $JOBS install &> $LOG_QEMU
    cd $TOP
}

initialize
build_qemu
