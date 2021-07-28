#!/bin/bash

# simple build scripts for compiling kernel on this repo
# supported config: merlin, lancelot, mojito
# toolchain used: proton clang-13
# note: change telegram CHATID to yours
# Thanks To Rama982 For Script

##------------------------------------------------------##

Help()
{
  echo "options:"
  echo "h     display this help"
  echo "d     name of *_defconfig file."
  echo "c     clone compiler."
  echo "n     disable CLANG LTO."
  echo "t     telegram bot token."
  echo
}

##------------------------------------------------------##

while getopts "hd:cnt:" option; do
  case $option in
    h) Help
       exit;;
    d) CONFIG=$OPTARG;;
    c) CLONE=true;;
    n) NOLTO=true;;
    t) TOKEN=$OPTARG;;
   \?) echo "Error: Invalid option"
       exit;;
  esac
done

if [ -z "$CONFIG" ] || [ -z "$TOKEN" ]; then
  echo 'Missing -d -t' >&2
  exit 1
fi

echo "This is your setup config"
echo
echo "Using defconfig: ""$CONFIG""_defconfig"
echo "Clone dependencies: $([[ ! -z "$CLONE" ]] && echo "true" || echo "false")"
echo "Disable LTO Clang: $([[ ! -z "$NOLTO" ]] && echo "true" || echo "false")"
echo
read -p "Are you sure? " -n 1 -r
! [[ $REPLY =~ ^[Yy]$ ]] && exit
echo

##------------------------------------------------------##

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
       -d "disable_web_page_preview=true" \
       -d "parse_mode=html" \
       -d text="$1"
}

##----------------------------------------------------------------##

tg_post_build() {
  curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
                      -F chat_id="$CHATID"  \
                      -F "disable_web_page_preview=true" \
                      -F "parse_mode=html" \
                      -F caption="$2"
}
##----------------------------------------------------------------##

zipping() {
  cd /root/AnyKernel || exit 1
  rm *.zip *-dtb *dtbo.img
  cp /root/arch/arm64/boot/Image.gz-dtb .
# cp /root/arch/arm64/boot/dtbo.img .
  zip -r9 "$ZIPNAME"-"${DATE}".zip *
  cd - || exit
}

##----------------------------------------------------------------##

build_kernel() {
  echo "-Styrofoam-X-Elzatta$CONFIG" > localversion
  make O=/root ARCH=arm64 "$DEFCONFIG"
  make -j"$PROCS" O=/root \
                  ARCH=arm64 \
                  CC=clang \
                  CROSS_COMPILE=aarch64-linux-gnu- \
                  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

##----------------------------------------------------------------##

if [[ $CLONE == true ]]
then
  echo "Cloning dependencies"
  mkdir /root/clang-llvm
  git clone https://github.com/kdrag0n/proton-clang --depth=1 /root/clang-llvm
  git clone https://github.com/Styrofoam-Kernel/AnyKernel3 -b mojito --depth=1 /root/AnyKernel
fi

#telegram env
CHATID=-1001311643504
BOT_MSG_URL="https://api.telegram.org/bot$TOKEN/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$TOKEN/sendDocument"

# env
export DEFCONFIG=$CONFIG"_defconfig"
export TZ="Asia/Jakarta"
export KERNEL_DIR=$(pwd)
export ZIPNAME="Styrofoam-Elzatta"
export IMAGE="/root/arch/arm64/boot/Image.gz-dtb"
export DATE=$(date "+%Y%m%d-%H%M")
export BRANCH="$(git rev-parse --abbrev-ref HEAD)"
export PATH="/root/clang-llvm/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(/root/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
export ARCH=arm64
export KBUILD_BUILD_USER=rama982
export COMMIT_HEAD=$(git log --oneline -1)
export PROCS=$(nproc --all)
export DISTRO=$(cat /etc/issue)
export KERVER=$(make kernelversion)

# start build
tg_post_msg "
Build is started
<b>OS: </b>$DISTRO
<b>Kernel Version : </b>$KERVER
<b>Date : </b>$(date)
<b>Device : </b>$CONFIG
<b>Host : </b>$KBUILD_BUILD_HOST
<b>Core Count : </b>$PROCS
<b>Branch : </b>$BRANCH
<b>Top Commit : </b>$COMMIT_HEAD
"

[[ $NOLTO == true ]] && sed -ir 's/^CONFIG_LTO_CLANG=.*/CONFIG_LTO_CLANG=n/' arch/arm64/configs/"$DEFCONFIG"

BUILD_START=$(date +"%s")

build_kernel

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

if [[ -f $IMAGE ]]
then
  zipping
  ZIPFILE=$(ls /root/AnyKernel/*.zip)
  MD5CHECK=$(md5sum "$ZIPFILE" | cut -d' ' -f1)
  tg_post_build "$ZIPFILE" "
<b>Build took : </b>$((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)
<b>Compiler: </b>$(grep LINUX_COMPILER /root/include/generated/compile.h  |  sed -e 's/.*LINUX_COMPILER "//' -e 's/"$//')
<b>MD5 Checksum : </b><code>$MD5CHECK</code>
"
else
  tg_post_msg "<b>Build took : </b>$((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s) but error"
fi

# reset git
git reset --hard HEAD

##----------------*****-----------------------------##
