#!/bin/bash

MAKE_FLAGS=-j8

TOP_DIR=`pwd`

LC_LANG=C

# Setup directories
SRC_DIR=${TOP_DIR}/src

BUILD_DIR=${TOP_DIR}/build

LOG_DIR=${BUILD_DIR}/log

TARGET=arm-v7ar-linux-gnueabi

# The GCC target CPU tunning
TARGET_ARCH=armv7-a
TARGET_MODE=arm
TARGET_FPU=vfpv3
TARGET_TUNE=cortex-a15
TARGET_FLOAT=softfp

# define installation prefix
PREFIX_CROSS=${TOP_DIR}/${TARGET}

# define path to cross tools binaries
TOOLS_DIR=$PREFIX_CROSS/bin

# define SYSROOT
SYSROOT=${PREFIX_CROSS}/${TARGET}/sys-root

CROSS_TOOLS_PREFIX=${TOOLS_DIR}/${TARGET}

# define kernel version for glibc
LINUX_VERSION=4.0
LINUX_SRC=${SRC_DIR}/linux-stable

# define linux target architecture
LINUX_ARCH=arm

BUILD_DATE=`date +%d-%m-%Y`

abort() {
    echo $1
    exec false
}

check_success() {
   if [ $? -ne 0 ]; then
      echo "Failed"
      exit 1
   fi
}

check_build_dir ()
{
    if [ -n $1 ]; then
        if [ -d $1 ]; then
            echo "Drop Dir $1" >> $2 2>&1
            rm -rfv $1 >> $2 2>&1;
        fi

        echo "Create Dir $1" >> $2 2>&1
        mkdir -pv $1 >> $2 2>&1;
    fi
}

create_dirs(){
    echo "Current dir:          "$TOP_DIR
    echo "The dir with sources: "$SRC_DIR
    echo "The build dir:        "$BUILD_DIR

    mkdir -p ${SYSROOT}/
    mkdir -p $SRC_DIR

    if ! [ -d "${SYSROOT}/" ]; then
        abort "Error: cannnot create the sysroot dir '$SYSROOT'"
    fi

    if ! [ -d $BUILD_DIR ] ; then
        echo  "BUILD_DIR not found, create $BUILD_DIR"
        mkdir $BUILD_DIR
    fi

    if ! [ -d ${LOG_DIR} ] ; then
        echo  "LOG_DIR not found, create ${LOG_DIR}"
        mkdir -p ${LOG_DIR}
    fi
}

default_setup_source_gcc() {
    cd $SRC_DIR
    git clone git://gcc.gnu.org/git/gcc.git
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_binutils-gdb() {
    cd $SRC_DIR
    git clone git://sourceware.org/git/binutils-gdb.git
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_glibc() {
    cd $SRC_DIR
    git clone git://sourceware.org/git/glibc.git
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_gmp() {
    cd $SRC_DIR
    wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.lz && tar xfv gmp-6.1.2.tar.lz && mv gmp-6.1.2 gmp
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_linux() {
    cd $SRC_DIR
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_mpfr() {
    cd $SRC_DIR
    wget http://www.mpfr.org/mpfr-current/mpfr-3.1.5.tar.bz2 && tar xfv mpfr-3.1.5.tar.bz2 && mv mpfr-3.1.5 mpfr
    retval=$?
    cd $TOP_DIR
    return $retval
}

default_setup_source_mpc() {
set +x
    cd $SRC_DIR
    git clone https://scm.gforge.inria.fr/anonscm/git/mpc/mpc.git && cd mpc && autoreconf -ifs
    retval=$?
    cd $TOP_DIR
    return $retval
}


# common function to build toolchain components
# with configure, make, make install.
#
# arguments:
#           $1 - component name
#           $2 - list of option to ./configure script

build () {

    TOOL_NAME=$1
    TOOL_BUILD_DIR=${BUILD_DIR}/${TOOL_NAME}
    LOG=$LOG_DIR/${TOOL_NAME}.log
    TOOL_SRC_DIR=${SRC_DIR}/${TOOL_NAME}

    echo
    echo "-= [${TOOL_NAME}] =-"

    if [ -f $LOG ]; then
        rm $LOG
    fi;

    # check if there is a function to prepare source code for current component
    if [ ! -d $TOOL_SRC_DIR ]; then
        echo -n "[${TOOL_NAME}] Setting source code"
        if [ "$(type -t setup_source_${var})" = function ]; then
            setup_source_${TOOL_NAME} >> $LOG 2&>1
            check_success
        else
            default_setup_source_${TOOL_NAME} >> $LOG 2&>1
            check_success
        fi
        echo " Done"
    fi

    cd $BUILD_DIR

    check_build_dir $TOOL_BUILD_DIR $LOG

    cd $TOOL_BUILD_DIR

    echo -n "[${TOOL_NAME}] Configure:"
    $TOOL_SRC_DIR/configure $2  >> $LOG 2>&1
    check_success
    echo " Done"

    echo -n "[${TOOL_NAME}] Build:"
    make ${MAKE_FLAGS} >> $LOG 2>&1
    check_success
    echo "Done"

    echo -n "[${TOOL_NAME}] Install:"
    make install >> $LOG 2>&1
    check_success
    echo "Done"

    cd $TOP_DIR
}

build_gmp(){

    CPPFLAGS=-fexceptions \
    build gmp "--prefix=$PREFIX_CROSS \
               --enable-maintainer-mode \
               --enable-cxx \
               --disable-shared \
               --enable-static"
}

build_mpfr(){

    build mpfr "--prefix=$PREFIX_CROSS \
                --with-gmp=$PREFIX_CROSS \
                --disable-shared \
                --enable-static"
}

build_mpc(){

    build mpc "--prefix=$PREFIX_CROSS \
               --with-gmp=$PREFIX_CROSS \
               --with-mpfr=$PREFIX_CROSS \
               --disable-shared \
               --enable-static"
}

build_binutils() {
    build binutils-gdb "--target=$TARGET \
                        --prefix=$PREFIX_CROSS \
                        --disable-nls \
                        --with-sysroot=$SYSROOT \
                        --enable-poison-system-directories \
                        --disable-gdb \
                        --disable-libdecnumber \
                        --disable-readline \
                        --disable-sim"
}

build_gcc_stage_1(){
    build gcc "--target=$TARGET \
               --prefix=$PREFIX_CROSS \
               --disable-libssp \
               --disable-libstdcxx-pch \
               --with-gnu-as \
               --with-gnu-ld \
               --disable-nls \
               --disable-shared \
               --disable-libatomic \
               --disable-libssp \
               --disable-libgomp \
               --disable-libquadmath \
               --disable-decimal-float \
               --disable-libffi \
               --disable-threads \
               --enable-languages=c \
               --with-sysroot=$SYSROOT \
               --with-gmp=$PREFIX_CROSS \
               --with-mpfr=$PREFIX_CROSS \
               --disable-libgomp \
               --with-newlib \
               --enable-stage1-checking \
               --with-arch=${TARGET_ARCH} \
               --with-mode=${TARGET_MODE} \
               --with-tune=${TARGET_TUNE} \
               --with-fpu=${TARGET_FPU} \
               --with-float=${TARGET_FLOAT}"
}

install_linux_headers(){
    echo "Installing Linux headers"
    cd $BUILD_DIR

    # define linux headers log file
    LINUX_HEADERS_LOG=${LOG_DIR}/linux_headers.log

    if ! [ -d $LINUX_SRC ] ; then
        abort "Error: cannot find the kernel source dir '$LINUX_SRC'"
    fi

    LINUX_HEADERS_BUILD_DIR="$BUILD_DIR/`basename ${LINUX_SRC}`.linux_headers"

    check_build_dir $LINUX_HEADERS_BUILD_DIR $LINUX_HEADERS_LOG

    cp -rf $LINUX_SRC/* $LINUX_HEADERS_BUILD_DIR
    cd $LINUX_HEADERS_BUILD_DIR

    make ARCH=${LINUX_ARCH} CROSS_COMPILE=${CROSS_TOOLS_PREFIX}- INSTALL_HDR_PATH="${SYSROOT}/usr" headers_install > ${LINUX_HEADERS_LOG} 2>&1
    check_success
    echo "Done"
    cd $TOP_DIR
}

build_glibc(){

    CC=${CROSS_TOOLS_PREFIX}-gcc \
    CXX=${CROSS_TOOLS_PREFIX}-g++ \
    AR=${CROSS_TOOLS_PREFIX}-ar \
    NM=${CROSS_TOOLS_PREFIX}-nm \
    RANLIB=${CROSS_TOOLS_PREFIX}-ranlib \
    DESTDIR=${SYSROOT}/ \
    build glibc "--prefix=/usr \
                 --host=${TARGET} \
                 --enable-kernel=$LINUX_VERSION \
                 --with-__thread \
                 --with-tls \
                 --disable-werror \
                 --enable-obsolete-rpc"

    #install glibc headers
    #TODO: do proper headers installation
    cd $BUILD_DIR/glibc
    DESTDIR=${SYSROOT}/ make install-headers  >> ${LOG_DIR}/glibc.log 2>&1
    check_success
    cd $TOP_DIR
}

build_gcc(){
    DEBUG_FLAGS="-g3 -ggdb3 -Og -fvar-tracking-assignments -gdwarf-4"

    CFLAGS=${DEBUG_FLAGS} \
    CXXFLAGS=${DEBUG_FLAGS} \
    CPPFLAGS=${DEBUG_FLAGS} \
    CFLAGS_FOR_TARGET=${DEBUG_FLAGS} \
    CXXFLAGS_FOR_TARGET=${DEBUG_FLAGS} \
    STAGE1_CXXFLAGS=${DEBUG_FLAGS} \
    build gcc "--target=$TARGET \
               --prefix=$PREFIX_CROSS \
               --enable-threads \
               --enable-languages=c,c++ \
               --enable-shared \
               --enable-lto \
               --enable-symvers=gnu \
               --enable-__cxa_atexit \
               --enable-plugin \
               --enable-long-long \
               --enable-checking=yes \
               --disable-libssp \
               --disable-libstdcxx-pch \
               --disable-nls \
               --disable-libffi \
               --disable-libquadmath \
               --disable-libgomp \
               --with-sysroot=$SYSROOT \
               --with-build-time-tools=$TOOLS_DIR \
               --with-gmp=$PREFIX_CROSS \
               --with-mpfr=$PREFIX_CROSS \
               --with-system-zlib \
               --with-glibc-version=2.22 \
               --with-arch=${TARGET_ARCH} \
               --with-mode=${TARGET_MODE} \
               --with-tune=${TARGET_TUNE} \
               --with-fpu=${TARGET_FPU} \
               --with-float=${TARGET_FLOAT}"
}

# workaround for Gentoo
unset LD_LIBRARY_PATH
export WANT_AUTOCONF=2.64
export WANT_AUTOMAKE=1.11

create_dirs
build_gmp
build_mpfr
build_mpc
build_binutils
build_gcc_stage_1
install_linux_headers
build_glibc
build_gcc

# creating archive with toolchain

if [ -f -$BUILD_DATE.tar.gz ]; then
    rm -fv ${TARGET}-$BUILD_DATE.tar.gz
fi

tar cfj ${TARGET}-$BUILD_DATE.tar.gz ${TARGET}

echo "*** FINISHED ***"
