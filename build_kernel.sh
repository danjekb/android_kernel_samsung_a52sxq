#!/bin/bash

export ARCH=arm64

# ---- User Config ----
PROJECT_VERSION="0.1-exp"
DEVICE="a52sxq"
VARIENT="vanilla"
# ---------------------

DATE="$(date +"%Y-%m-%d_%H-%M-%S")"
IMAGE_SOURCE="./out/arch/arm64/boot/Image"
FINAL_IMAGE="$EXPORT_DIR/Image"
ZIP_NAME="WonderfulKernel-${DEVICE}-${PROJECT_VERSION}-${DATE}.zip"

# ---- Environment ----
export LC_ALL=C
export KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y WERROR=0 CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
export OUT_DIR=$(pwd)/out

export LOCALVERSION="-Wonderful-${PROJECT_VERSION}-${VARIENT}"
export KBUILD_BUILD_USER="Jarek"
export KBUILD_BUILD_HOST="SlopKernel-CI"

echo ""
echo "===== Building Wonderful Kernel ====="
echo "Version: Wonderful-${PROJECT_VERSION}-${VARIENT}"
echo "======================================"
echo ""

if [ "$1" == "clean" ]; then
    if [ -d "$OUT_DIR" ]; then
        make -C $(pwd) O=$OUT_DIR ARCH=arm64 clean
    fi
    echo "Cleaning is done."
else

if [ "$1" == "menuconfig" ]; then
    mkdir -p $OUT_DIR

    if [ ! -f "$OUT_DIR/.config" ]; then
        make -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=$CLANG_TRIPLE vendor/a52sxq_eur_open_defconfig
    fi

    make -C $(pwd) O=$OUT_DIR ARCH=arm64 menuconfig
    exit 0
fi

# 1. Wygenerowanie konfiguracji przy użyciu pełnego zestawu LLVM
echo ">> Configuring defconfig..."
make -j$(nproc) -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=$CLANG_TRIPLE vendor/a52sxq_eur_open_defconfig 2>&1 | tee build.log

# 2. Właściwa kompilacja jądra oraz modułów przy użyciu LLVM
echo ">> Compiling kernel..."
make -j$(nproc) -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=$CLANG_TRIPLE 2>&1 | tee -a build.log

# Weryfikacja czy obraz jądra powstał w katalogu wyjściowym (OUT_DIR)
if [[ ! -f "$IMAGE_SOURCE" ]]; then
    echo "Image not found at $IMAGE_SOURCE. Build failed."
    exit 1
fi

# Eksport surowego obrazu binarnego
mkdir -p "$EXPORT_DIR"
cp "$IMAGE_SOURCE" "$FINAL_IMAGE"

# Pakowanie AnyKernel3 do gotowej paczki flashowalnej ZIP
if [[ -d "$ANYKERNEL_DIR" ]]; then
    echo ">> Packaging AnyKernel3 ZIP..."
    cp "$IMAGE_SOURCE" "$ANYKERNEL_DIR/Image"
    
    # Kopiowanie dtbo.img oraz innych powiązanych obrazów jeśli istnieją
    [ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img "$ANYKERNEL_DIR/"
    
    cd "$ANYKERNEL_DIR"
    zip -r9 "$EXPORT_DIR/$ZIP_NAME" * -x "*.git*" "*.zip" > /dev/null
    cd - > /dev/null
fi

echo ""
echo "Build successful!"
echo "Exported to: $FINAL_IMAGE"
if [[ -f "$EXPORT_DIR/$ZIP_NAME" ]]; then
    echo "Flashable zip: $EXPORT_DIR/$ZIP_NAME"
fi
echo ""
echo "Done."
fi
