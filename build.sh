#! /bin/bash
# Copyright (C) 2020 Starlight
#

export DEVICE="Vince"
export CONFIG="vince-perf_defconfig"
export JOBS=$(nproc --all)
export CHANNEL_ID="$CHAT_ID"
export TELEGRAM_TOKEN="$BOT_API_KEY"
export TC_PATH="$HOME/TC"
export ZIP_DIR="$HOME/AK3"
export IS_MIUI="no"
export KERNEL_DIR="$HOME/kernel"
export KBUILD_BUILD_USER="StormbreakerCI-BOT"
export GCC_COMPILE="yes" 
export CLANG_VER="$clang_ver"
export KBUILD_BUILD_HOST="Stormbreaker-HQ"
export REVISION="R-boobs-16ms"

#==============================================================
#===================== Function Definition ====================
#==============================================================
#======================= Telegram Start =======================
#==============================================================

# Upload buildlog to group
tg_erlog()
{
	curl -F document=@"$LOG"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID \
			-F caption="Build ran into errors after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds, plox check logs"
}

# Upload zip to channel
tg_pushzip() 
{
	curl -F document=@"$ZIP"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID \
			-F caption="Build Finished after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds"
}

# Send Updates
function tg_sendinfo() {
	curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
		-d "parse_mode=html" \
		-d text="${1}" \
		-d chat_id="${CHANNEL_ID}" \
		-d "disable_web_page_preview=true"
}

# Send a sticker
function start_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
        -d sticker="CAACAgUAAxkBAAIEy19DxNr5C-iHBs3Ggp5H_pX3KOwdAAIgAQACLPkBVtu34-6AeoBIGwQ" \
        -d chat_id=$CHANNEL_ID
}

#======================= Telegram End =========================
#======================== Clone Stuff ==========================

function clone_tc() {
[ -d ${TC_PATH} ] || mkdir ${TC_PATH}

if [ "$GCC_COMPILE" == "yes" ]; then
	git clone --depth=1 https://github.com/arter97/arm64-gcc ${TC_PATH}/gcc64
	git clone --depth=1 https://github.com/arter97/arm32-gcc ${TC_PATH}/gcc32
	export PATH="${TC_PATH}/gcc64/bin:${TC_PATH}/gcc32/bin:$PATH"
	export STRIP="${TC_PATH}/gcc64/aarch64-elf/bin/strip"
	export COMPILER="Arter97's Latest GCC Compiler" 
else
	if [ "$CLANG_VER" == "12" ]; then
		git clone --depth=1 https://github.com/kdrag0n/proton-clang.git ${TC_PATH}/clang
		export PATH="${TC_PATH}/clang/bin:$PATH"
		export STRIP="${TC_PATH}/clang/aarch64-linux-gnu/bin/strip"
		export COMPILER="Kdrag0n's Latest Proton Clang"
	else
		git clone --depth=1 https://github.com/Unitrix-Kernel/unitrix-clang.git ${TC_PATH}/clang
		export PATH="${TC_PATH}/clang/bin:$PATH"
		export STRIP="${TC_PATH}/clang/aarch64-linux-gnu/bin/strip"
		export COMPILER="Starlight's Kang 11"
	fi
fi

rm -rf $ZIP_DIR && git clone https://github.com/stormbreaker-project/AnyKernel3 -b vince $ZIP_DIR
}

function clone_kernel(){

mkdir -p $KERNEL_DIR
git clone --depth=1 https://${GITHUB_USER}@github.com/aosp-star/kernel_xiaomi_vince -b staging $KERNEL_DIR
cd $KERNEL_DIR

}

#==============================================================
#=========================== Make =============================
#========================== Kernel ============================
#==============================================================

build_kernel() {
DATE=`date`
BUILD_START=$(date +"%s")
make O=out ARCH=arm64 "$CONFIG"

if [ "$GCC_COMPILE" == "yes" ]; then
	make -j$(nproc --all) O=out \
			      ARCH=arm64 \
			      CROSS_COMPILE=aarch64-elf- \
			      CROSS_COMPILE_ARM32=arm-eabi- |& tee -a $LOG
else
	make -j$(nproc --all) O=out \
			      ARCH=arm64 \
			      CC=clang \
			      CROSS_COMPILE=aarch64-linux-gnu- \
			      CROSS_COMPILE_ARM32=arm-linux-gnueabi- |& tee -a $LOG
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
}

#==================== Make Flashable Zip ======================

function make_flashable() {

if [ "$IS_MIUI" == "yes" ]; then
    for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
        "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
        "$KERNEL_DIR/scripts/sign-file" sha512 \
                "$KERNEL_DIR/out/signing_key.priv" \
                "$KERNEL_DIR/out/signing_key.x509" \
                "${MODULES}"
        case ${MODULES} in
                */wlan.ko)
		cp "${MODULES}" "${VENDOR_MODULEDIR}/pronto_wlan.ko"
            ;;
        esac
    done
    echo -e "(i) Done moving wifi modules"
fi

cd $ZIP_DIR
make clean &>/dev/null
cp $KERN_IMG $ZIP_DIR/zImage
NAME="StormBreaker-Kernel"
DATE=$(date "+%d%m%Y-%I%M")
STORM_ZIP_NAME=${NAME}-${KERN_VER}-${DEVICE}-${DATE}.zip
EXCLUDE="Storm* *placeholder* .git"
rm -rf .git
zip -r9 "$STORM_ZIP_NAME" . -x $EXCLUDE &> /dev/null
ls
ZIP=$(echo *.zip)
tg_pushzip

}

#========================= Build Log ==========================

mkdir -p $HOME/build
export LOG=$HOME/build/build${REVISION}.txt

#===================== End of function ========================
#======================= definition ===========================

tg_sendinfo "$(echo -e "Build has been triggered for $DEVICE 🔫\n>> Cloning Compiler & Kranul")"
clone_tc
clone_kernel

COMMIT=$(git log --pretty=format:'"%h : %s"' -1)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
export KERN_VER=$(echo "$(make kernelversion)")

start_sticker
tg_sendinfo "$(echo -e "======= <b>$DEVICE</b> =======\n
Build-Host         :- <b>$KBUILD_BUILD_HOST</b>
Build-User         :- <b>$KBUILD_BUILD_USER</b>
Build-System    :- <b>$(uname -n)</b>
With jobs           :- <b>$JOBS</b>
Build number   :- <b>$REVISION</b>\n
Version         :- <u><b>$KERN_VER</b></u>
Compiler      :- <i>$COMPILER</i>\n
on Branch   :- <b>$BRANCH</b>
Commit       :- <b>$COMMIT</b>\n")"

build_kernel

# Check if kernel img is there or not and make flashable accordingly

if ! [ -a "$KERN_IMG" ]; then
	tg_erlog
	exit 1
else
	make_flashable
fi
