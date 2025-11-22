#!/bin/bash
make loongarch64_ramdisk_defconfig
make -j$(nproc)
cp -v ./output/images/rootfs.ext2.gz ./ramdisk.gz
