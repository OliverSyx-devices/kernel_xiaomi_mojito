#!/bin/bash

#
# Script for building Android arm64 Kernel
#
#

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR"/out/arch/arm64/boot
LOG_FILE="$KERNEL_DIR"/build.log
DEFCONFIG=vendor/mojito_defconfig
export KBUILD_BUILD_USER="OliverSyx"

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set date and time
DATE=$(TZ=Asia/Jakarta date)
ZIP_DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M")

log_info() {
	echo -e "$1" | tee -a "$LOG_FILE"
}

# Set function for cloning repository
clone() {
	log_info "-> Kloning AnyKernel3..."
	git clone --depth=1 https://github.com/OliverSyx/AnyKernel3.git -b mojito 2>&1 | tee -a "$LOG_FILE"

	# Setup and apply patch KernelSU in root dir
	if ! [ -d "$KERNEL_DIR"/KernelSU-Next ]; then
		log_info "-> Mendownload dan mensetup KernelSU..."
		curl -LSs "https://raw.githubusercontent.com/manipvlator/KernelSU-Next/stable/kernel/setup.sh" | bash -s syscall 2>&1 | tee -a "$LOG_FILE"
	fi

	# Menggunakan Clang bawaan Server / Host PATH
	KBUILD_COMPILER_STRING=$(clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	export KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming_for_bc() {
	KERNEL_NAME="STRIX-mojito-bc-ksunext-$ZIP_DATE"
	export ZIP_NAME="$KERNEL_NAME.zip"
}

# Set function for starting compile
compile() {
	log_info "-> Memulai kompilasi kernel..."
	log_info "Compiler : $KBUILD_COMPILER_STRING"
	log_info "Core CPU : $PROCS"
	
	# Skrip langsung memanggil defconfig yang sudah kamu edit manual
	make O=out "$DEFCONFIG" 2>&1 | tee -a "$LOG_FILE"
	BUILD_START=$(date +"%s")
	
	# Kompilasi murni menggunakan Clang Host dengan LTO bawaan defconfig
	make -j"$PROCS" O=out \
			CROSS_COMPILE=aarch64-linux-gnu- \
			CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			LLVM=1 \
			LLVM_IAS=1 2>&1 | tee -a "$LOG_FILE"

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "$IMG_DIR"/Image ]; then
		log_info "Kernel sukses dikompilasi dalam $((DIFF / 60)) menit dan $((DIFF % 60)) detik."
	elif ! [ -f "$IMG_DIR"/Image ]; then
		log_info "Kernel gagal dikompilasi setelah $((DIFF / 60)) menit dan $((DIFF % 60)) detik. Silakan periksa berkas build.log"
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip_for_bc() {
	log_info "-> Membuat paket flashable zip AnyKernel3..."
	# Make sure there are no files like dtb, dtbo.img, Image, and .zip
	cd AnyKernel3 || exit
	rm -rf dtb dtbo.img Image *.zip
	cd ..

	# Move kernel image to AnyKernel3
	cat "$IMG_DIR"/dts/qcom/sm6150.dtb > AnyKernel3/dtb
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo.img
	mv "$IMG_DIR"/Image AnyKernel3/Image
	cd AnyKernel3 || exit

	# Archive to flashable zip
	zip -r9 "$ZIP_NAME" * -x .git README.md *.zip 2>&1 | tee -a "$LOG_FILE"

	# Prepare a final zip variable
	ZIP_FINAL="$ZIP_NAME"
	log_info "Zip pack sukses: $ZIP_FINAL"
	cd ..
}

# --- Alur Eksekusi Utama ---
rm -f "$LOG_FILE"

log_info "=========================================="
log_info "  STARTING KERNEL BUILD PROCESS"
log_info "  Date: $DATE"
log_info "=========================================="

clone
compile
set_naming_for_bc
gen_zip_for_bc

log_info "=========================================="
log_info "  BUILD PROCESS FINISHED"
log_info "=========================================="
