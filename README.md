# Steps to produce images

## AT91SAM9260-EK

- Git clone buildroot (2023.05 was used here)
- br-config becomes the .config at the root of this buildroot
- linux-config becomes output/build/linux-6.3.8/.config
- uboot-config becomes output/build/uboot-2022.04/.config
- uclibc-config becomes output/build/uclibc-1.0.43/.config

- Also git clone At91Bootstrap3 and compile separately, the one that comes with buildroot fails

Make all

Fixes:
`drivers/mtd/nand/raw/atmel_nand.c` in the uboot code needs `CONFIG_SYS_NAND_ECC_BASE` replaced with `ATMEL_BASE_ECC`
`arch/arm/mach-at91/include/mach/at91sam9260.h` needs an additional line `#define ATMEL_BASE_ECC          0xffffe800`


Do not use the stock dts/dtb file, use this at91sam9260ek.dts instead for nand+macb fixes

The intended memory map to write to flash is:
```
0x00000000 - 0x0003FFFF bootstrap       (256 KiB)
0x00040000 - 0x000BFFFF u-boot          (512 KiB)
0x000C0000 - 0x000FFFFF env             (256 KiB)
0x00100000 - 0x0013FFFF env_redundant   (256 KiB)
0x00140000 - 0x0017FFFF spare           (256 KiB)
0x00180000 - 0x001FFFFF dtb             (512 KiB)
0x00200000 - 0x007FFFFF kernel          (6 MiB)
0x00800000 - 0xxxxxxxxx rootfs          (All left)
```

Use SAM-BA 2.18 to write the images to the above addresses.

Once U-Boot boots, the following commands should produce a successful OS:

```
nand read 0x22000000 0x200000 0x6fffff
nand read 0x22700000 0x180000 0x5000
fdt addr 0x22700000; fdt resize
env set bootargs 'console=ttyS0,115200 earlyprintk mtdparts=atmel_nand:256k(bootstrap)ro,512k(uboot)ro,256k(env),256k(env_redundant),256k(spare),512k(dtb),6M(kernel)ro,26M(rootfs) root=/dev/mmcblk0 rootfstype=ext4 ro'
mw.l 0xFFFFFD08 0xA5000100
mw.l 0xFFFFFD00 0xA5000008

bootm 0x22000000 - 0x22700000

/etc/init.d/S40network start
```

The mw.l lines write to reset controller registers to reset peripherals using the NRST pin but not the CPU, which resets the ethernet phy and makes it available. Looks like there's code in both U-Boot and the Linux kernel to do this but I haven't figured it out.


Bonus: 

The `debian-armel.yaml` can be fed into this code (https://github.com/laroche/arm-devel-infrastructure) to produce a debian image which can be written to a USB stick (root=/dev/sda2). Issues with this:

- Read the issue in this code regarding disabling root (to enable local root login)
- 64MB isn't enough for apt update. You might need swap somewhere, or manually download deb files for any extra packages
- I haven't setup swap or removed the swap entry in fstab and this causes a panic with systemd. 

