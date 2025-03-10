#!/bin/bash

set -euo pipefail

git clone https://gitlab.gnome.org/GNOME/libxml2.git libxml2_ef709ce2
cd libxml2_ef709ce2; git checkout ef709ce2
mkdir obj-aflgo; mkdir obj-aflgo/temp
# custom $AFLGO
export AFLGO=/home/xk/Documents/aflgo
export SUBJECT=$PWD; export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/instrument/aflgo-clang; export CXX=$AFLGO/instrument/aflgo-clang++
export LDFLAGS=-lpthread
export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"

# 生成提交差异并提取目标
git diff -U0 HEAD^ HEAD > $TMP_DIR/commit.diff
wget https://raw.githubusercontent.com/jay/showlinenum/develop/showlinenum.awk
chmod +x showlinenum.awk
mv showlinenum.awk $TMP_DIR
cat $TMP_DIR/commit.diff |  $TMP_DIR/showlinenum.awk show_header=0 path=1 | grep -e "\.[ch]:[0-9]*:+" -e "\.cpp:[0-9]*:+" -e "\.cc:[0-9]*:+" | cut -d+ -f1 | rev | cut -c2- | rev > $TMP_DIR/BBtargets.txt

# 编译项目 编译器已经被hook了
./autogen.sh; make distclean
cd obj-aflgo; CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4

# 生成目标导向模糊测试配置
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/distance/gen_distance_orig.sh $SUBJECT/obj-aflgo $TMP_DIR xmllint

# 配置并重新编译
CFLAGS="-distance=$TMP_DIR/distance.cfg.txt" CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
set +e
mkdir in; cp $SUBJECT/test/dtd* in; cp $SUBJECT/test/dtds/* in
$AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out ./xmllint --valid --recover @@
