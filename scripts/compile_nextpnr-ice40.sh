# -- Compile nextpnr-ice40 script

NEXTPNR=nextpnr
COMMIT=c0f02563e8908f28aa8eaa5eef2b886c0a27a2ab
GITNEXTPNR=https://github.com/YosysHQ/nextpnr

# -- Setup
. $WORK_DIR/scripts/build_setup.sh

cd $UPSTREAM_DIR

# -- Clone the sources from github
test -e $NEXTPNR || git clone $GITNEXTPNR $NEXTPNR
git -C $NEXTPNR pull
git -C $NEXTPNR checkout $COMMIT
git -C $NEXTPNR log -1

# -- Copy the upstream sources into the build directory
rsync -a $NEXTPNR $BUILD_DIR --exclude .git

cd $BUILD_DIR/$NEXTPNR

if [ -e CMakeCache.txt ]
then
  echo "CMakeCache.txt exists!"
fi
rm -f CMakeCache.txt

# -- Compile it
if [ $ARCH == "darwin" ]; then
  cmake -DARCH=ice40 \
    -DBOOST_ROOT=/tmp/nextpnr \
    -DBoost_USE_STATIC_LIBS=ON \
    -DPYTHON_EXECUTABLE=/tmp/nextpnr/bin/python \
    -DPYTHON_LIBRARY=/tmp/nextpnr/lib/libpython3.7m.a \
    -DEigen3_DIR=/tmp/nextpnr/share/eigen3/cmake \
    -DBUILD_GUI=OFF \
    -DBUILD_HEAP=ON \
    -DCMAKE_EXE_LINKER_FLAGS='-fno-lto -ldl -lutil' \
    -DICEBOX_ROOT="$WORK_DIR/icebox" \
    -DSTATIC_BUILD=ON \
    .
    make -j$J CXX="$CXX" LIBS="-lm -fno-lto -ldl -lutil"
elif [ ${ARCH:0:7} == "windows" ]; then
    cmake \
    -DARCH=ice40 \
    -DICEBOX_ROOT="$WORK_DIR/icebox" \
    -DBUILD_HEAP=ON \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DBUILD_GUI=OFF \
    -DSTATIC_BUILD=ON \
    -DBoost_USE_STATIC_LIBS=ON \
    .
    make -j$J CXX="$CXX" LIBS="-static -static-libstdc++ -static-libgcc -lm"
else
    # patch -p1 < ${WORK_DIR}/build-data/linux/0001-cmake-fix-static-build.patch
    cmake \
        -DARCH=ice40 \
        -DICEBOX_ROOT="$WORK_DIR/icebox" \
        -DBUILD_HEAP=ON \
        -DBUILD_GUI=OFF \
        -DSTATIC_BUILD=ON \
        -DBoost_USE_STATIC_LIBS=ON \
        .
    make -j$J CXX="$CXX"

    # Install a copy of Python, since Python libraries are not compatible
    # across minor versions.
    mkdir libpython3
    cd libpython3
    for pkg in $(ls -1 ${WORK_DIR}/build-data/$ARCH/*.deb)
    do
        echo "Extracting $pkg..."
        ar p $pkg data.tar.xz | tar xvJ
    done
    mkdir -p $PACKAGE_DIR/$NAME
    mv usr/* $PACKAGE_DIR/$NAME
    cd ..
fi || exit 1

# -- Copy the executable to the bin dir
mkdir -p $PACKAGE_DIR/$NAME/bin
cp nextpnr-ice40$EXE $PACKAGE_DIR/$NAME/bin/nextpnr-ice40$EXE

# Do a test run of the new binary
$PACKAGE_DIR/$NAME/bin/nextpnr-ice40$EXE --up5k --package sg48 --pcf $WORK_DIR/build-data/test/top.pcf --json $WORK_DIR/build-data/test/top.json --asc /tmp/nextpnr/top.txt --pre-pack $WORK_DIR/build-data/test/top_pre_pack.py --seed 0 --placer heap
