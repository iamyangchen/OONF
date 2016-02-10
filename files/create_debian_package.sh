#!/bin/sh

# store source directory
SOURCE=$(git rev-parse --show-toplevel)

# handle script input and variables
: ${BUILD:=oonf_build_debian}

BUILDDIR=/tmp/${BUILD}

if [ "$#" -eq "0" ]
then
        TARGET=olsrd2
else
        TARGET=${1}
fi

if [ "${TOOLCHAIN}" != "" ]
then
    echo "Using toolchain file: ${TOOLCHAIN}"
    TOOLCHAIN="-D CMAKE_TOOLCHAIN_FILE=`realpath ${TOOLCHAIN}`"
fi

if [ "${ARCH}" != "" ]
then
    echo "Using architecture: ${ARCH}"
    ARCH="-a${ARCH}"
fi

# calculate version and tarball names
VERSION=`git describe --abbrev=0| sed -e "s/^v//"`
FULLVERSION=`git describe`

TARPREFIX=${TARGET}_${VERSION}
TARBALL=${BUILDDIR}/${TARPREFIX}.orig.tar.gz

# check if target is there and prepared for a debian package
if [ ! -d ${SOURCE}/src/${TARGET} ]
then
    echo "Could not find target '${TARGET}'"
    exit 1
fi

if [ ! -f ${SOURCE}/src/${TARGET}/debian_changelog ]
then
    echo "Could not find target '${TARGET}' debian changelog"
    exit 1
fi

# create clean build directory
if [ -d ${BUILDDIR} ]
then
    echo "remove ${BUILDDIR}"
    rm -r ${BUILDDIR}
fi

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

# create directory structure
mkdir build

# build tarball of current source
cd build

cmake -DTARBALL=${TARBALL} -DTARPREFIX=${TARPREFIX} ${SOURCE}
make targz

cd ${BUILDDIR}

# uncompress tarball
tar xf ${TARBALL}

# build debian directory from template
cd ${TARPREFIX}

cp ${SOURCE}/src/${TARGET}/debian_changelog ./debian/changelog
cp ${SOURCE}/src/${TARGET}/debian_control ./debian/control
cp ${SOURCE}/files/default_licence.txt ./debian/copyright

# adapt changelog template
sed -i  -e "s@SHORTVERSION@${VERSION}@" \
        -e "s@FULLVERSION@${FULLVERSION}@" \
        -e "s@DATETIME@`date -R`@" \
        ./debian/changelog

# adapt rules template
sed -i  -e "s@SOURCEDIR@${BUILDDIR}/${TARPREFIX}@" \
        -e "s@SOURCETOOLCHAIN@${TOOLCHAIN}@" \
        -e "s@TARGETNAME@${TARGET}@" \
        -e "s@INSTALLDESTDIR@${BUILDDIR}/${TARPREFIX}/debian/${TARGET}@" \
        ./debian/rules

# create debian package
debuild -us -uc ${ARCH}

# copy package to source directory
cp ${BUILDDIR}/*.deb ${SOURCE}
