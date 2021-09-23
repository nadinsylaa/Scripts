#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
ZIPNAME="StyErnels"

# The codename of the device
DEVICE="merlin"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=merlin_defconfig

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

## Set defaults first
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
token=$TELEGRAM_TOKEN
export KBUILD_BUILD_HOST CI_BRANCH

## Export CI Env
export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
export CI_BRANCH=$DRONE_BRANCH
export CHATID="-1001311643504"

#Check Kernel Version
KERVER=$(make kernelversion)


# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
		msg "|| Cloning GCC ||"
		git clone --depth=1 https://github.com/silont-project/aarch64-elf-gcc -b arm64/11 gcc64
		git clone --depth=1 https://github.com/silont-project/arm-eabi-gcc -b arm/11 gcc32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/nadinsylaa/AnyKernel3.git -b merlin
}

##------------------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="NadinAlissa"
	export KBUILD_BUILD_HOST="Korban-Janji"
	export ARCH=arm64
	export SUBARCH=arm64

	KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
	PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH

	export CROSS_COMPILE_ARM32=$GCC32_DIR/bin/arm-eabi-
	export CROSS_COMPILE=$GCC64_DIR/bin/aarch64-elf-
	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"
}

##----------------------------------------------------------##

build_kernel() {

	tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>" "$CHATID"

	msg "|| Started Compilation ||"
	BUILD_START=$(date +"%s")
	make O=out $DEFCONFIG
	make -j"$PROCS" O=out

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ]
	    then
	    	msg "|| Kernel successfully compiled ||"
		gen_zip
	else
		tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
	fi

}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-$DEVICE-"$DRONE_BUILD_NUMBER" ./* -x .git README.md

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$DRONE_BUILD_NUMBER.zip"
	tg_post_build "$ZIP_FINAL" "$CHATID" "✅ Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	cd ..
}

clone
exports
build_kernel

##----------------*****-----------------------------##
