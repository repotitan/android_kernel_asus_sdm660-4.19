export PATH="$HOME/zyc-clang/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/zyc-clang/lib"
SECONDS=0
ZIPNAME="Bhunter_X01BD-KSU-$(date '+%Y%m%d-%H%M').zip"
DEFCONFIG="asus/X01BD_defconfig"
LINUXVER=$(make kernelversion)

# Set Date
DATE=$(TZ=Asia/Kolkata date +"%Y-%m-%d")
# if unset
[ -z $IS_CI ] && IS_CI="false"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

if ! [ -d "$HOME/zyc-clang" ]; then
echo "ZyC Clang not found! Cloning..."
wget -q https://github.com/ZyCromerZ/Clang/releases/download/17.0.0-20230725-release/Clang-17.0.0-20230725.tar.gz -O "zyc-clang.tar.gz"
mkdir ~/zyc-clang
tar -xf zyc-clang.tar.gz -C ~/zyc-clang
rm -rf zyc-clang.tar.gz
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
make O=out ARCH=arm64 $DEFCONFIG savedefconfig
cp out/defconfig arch/arm64/configs/$DEFCONFIG
echo -e "\nRegened defconfig succesfully!"
exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
echo -e "\nClean build!"
rm -rf out
fi

MK_FLAGS="
O=out
ARCH=arm64
CC=clang
LD=ld.lld
AR=llvm-ar
AS=llvm-as
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump 
STRIP=llvm-strip
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
CLANG_TRIPLE=aarch64-linux-gnu-
"

mkdir -p out
make $(echo $MK_FLAGS) $DEFCONFIG
make -j$(nproc --all) $(echo $MK_FLAGS) Image.gz-dtb

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git clone -q https://github.com/texascake/AnyKernel3 -b eas-old AnyKernel3
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cd AnyKernel3

cp -af anykernel-real.sh anykernel.sh
sed -i "s/kernel.string=.*/kernel.string=Bhunter-STABLE/g" anykernel.sh
sed -i "s/kernel.for=.*/kernel.for=perf/g" anykernel.sh
sed -i "s/kernel.made=.*/kernel.made=Bhunter/g" anykernel.sh
sed -i "s/kernel.version=.*/kernel.version=$LINUXVER/g" anykernel.sh
sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh

zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
# Rissu: skip cleaning up out/arch/arm64/boot dir
if [[ "$IS_CI" = "false" ]]; then
rm -rf out/arch/arm64/boot AnyKernel3
fi
else
echo -e "\nCompilation failed!"
fi
