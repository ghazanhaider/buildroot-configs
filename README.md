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


### Bonus: 

The `debian-armel.yaml` can be fed into this code (https://github.com/laroche/arm-devel-infrastructure) to produce a debian image which can be written to a USB stick (root=/dev/sda2). Issues with this:

- Read the issue in this code regarding disabling root (to enable local root login)
- 64MB isn't enough for apt update. You might need swap somewhere, or manually download deb files for any extra packages
- I haven't setup swap or removed the swap entry in fstab and this causes a panic with systemd. 



## AT91SAM9261-EK

- Git clone buildroot (2023.05 was used here)
- br-config becomes the .config at the root of this buildroot
- linux-config becomes output/build/linux-6.3.8/.config
- uboot-config becomes output/build/uboot-2022.04/.config
- uclibc-config becomes output/build/uclibc-1.0.43/.config
- at91dataflashboot-config becomes output/build/at91dataflashboot-1.05/.config
- IGNORE: at91bootstrap-config beomces output/build/at91bootstrap3-v3.10.3/.config

Notes: 
- IGNORE: AT91Bootstrap3 should be configured to boot from Dataflash and write it to Dataflash (address 0x0).
- Use at91dataflashboot-1.05 instead of AT91Bootstrap3 for this board
- UBoot and Kernel can both be written to NAND in the usual spots
- The interrupt pin for Ethernet (PC11) conflicts with CTS for usart0. You can only use non-hardware usart0 with ethernet
- Do NOT configure Driver Model for Ethernet. That blocks DM9000.
- You will not see a DM9000/Davicom ethernet option in uboot config, it is selected automatically by the board.


Make all

TODO Fixes:
- I have the rev 0.006 board. The Errata for the chip says that it can only boot from Dataflash with no workarounds.
- There's a jumper J21 that selects between SD card and Dataflash.
- To boot from an SD card, I must have jumper J21 at 1-2 during boot to UBoot.
- The clock for SPI conflicts with the clock for MMC0. I've disabled SPI which disables Linux kernel's access to the Dataflash as well as to the touch controller. Maybe a fix here is to use the SD card using SPI mode and ignore MMC0?


Do not use the stock dts/dtb file, use this at91sam9261ek.dts.



## AT91SAM9G45-EKES

- Git clone buildroot (2023.02.2 was used here)
- Copy br-config to be .config at the root of this buildroot
- make nconfig and save
- Copy linux-config to output/build/linux-6.4.2/.config
- Copy uboot-config to output/build/uboot-2022.04/.config
- Copy uclibc-config to output/build/uclibc-1.0.43/.config
- Copy at91bootstrap3-config to output/build/at91bootstrap3-v3.10.3/.config

Make all

- Use sam-ba 2.18 to write at91bootstrap.bin to the Dataflash at address 0
- Use sam-ba to write u-boot.bin to Dataflash at 0x40000
- Use sam-ba to write the kernel file uImage to the NAND device at 0x200000
- Do not use the at91sam9m10g45ek.dtb file produced by the kernel, compile the one in this repository like so:
```
cd buildroot-configs
./dtscompile.sh at91sam9G45ek/at91sam9m10g45ek.dts /root/buildroot/output/build/linux-6.4.2/
# I had cloned buildroot to /root, please change this path to the correct location for you.
# The modified dtb file is placed in the buildroot-configs/at91sam9G45ek/ folder 
```
- Use sam-ba to write this devicetree file at91sam9m10g45ek.dtb to NAND at 0x180000
Write the image rootfs.ext2 to an SD card using dd or Balena (not to a partition but to the raw SD
- Boot away

Notes:
- Framebuffer, ethernet works
- Audio needs to be tested
- The chip has a PIT timer but Linux prefers to use up two TCB timers to make it better (higher res). I have both compiled but it looks like the TCB pair is used, which takes away two timers from our applications but the kernel seems to run very nicely.
- We cannot specify a MAC address in the devicetree because macb runs well without the ethernet-phy specified, so we'll need to put a MAC address in /etc/network/interfaces instead, or use the command macchanger after boot.
- The ethernet on boot reports irq=POLLING but once it comes up looks like it is using IRQ 28, not sure why earlier it reports irq=POLLING

The two memory bank problem:
- 9G45 has two DRAM regions 0x20000000 and 0x70000000. My board has both populated (MN6 MN7 and MN8 MN9)
- If your board also has 4 DDR2 chips populated, enabled the second bank by adding line `select BOARD_HAS_2_BANKS` into file `board/at91sam9m10g45ek/Config.in.board` and then run make at91bootstrap3-menuconfig and set MEM_BANK to 0x70000000 and MEM_BANK2 to 0x20000000
- AT91Bootstrap3 also only initializes the first memory bank. To fix this, edit this file `board/at91sam9m10g45ek/at91sam9m10g45ek.c`:
```
        /* DDRAM2 Controller initialize */
        //ddram_initialize(AT91C_BASE_DDRSDRC, AT91C_DDRAM_BASE_ADDR, &ddramc_reg);
        ddram_initialize(AT91C_BASE_DDRSDRC0, AT91C_BASE_CS6, &ddramc_reg);
        ddram_initialize(AT91C_BASE_DDRSDRC1, AT91C_BASE_CS1, &ddramc_reg);
```
- To change the load address of a kernel, just run this command instead of recompiling everything (in the linux-6.4.2 folder):
`mkimage -A arm -O linux -T kernel -C none -a 0x22000000 -e 0x22000000 -n "mykern" -d arch/arm/boot/zImage uImage`

- You'll need to change the boot command to something like this:
```
mem=128M@0x70000000 mem=128M@0x20000000 console=ttyS0,115200 earlyprintk mtdparts=atmel_nand:256k(bootstrap)ro,512k(uboot)ro,256k(env),256k(env_redundant),256k(spare),512k(dtb),6M(kernel)ro,-(rootfs) root=/dev/mmcblk1 rootfstype=ext4 ro
```

- When it works, you see this during boot:
```
Zone ranges:
  Normal   [mem 0x0000000020000000-0x0000000027ffffff]
  HighMem  [mem 0x0000000028000000-0x0000000077ffffff]
Movable zone start for each node
Early memory node ranges
  node   0: [mem 0x0000000020000000-0x0000000027ffffff]
  node   0: [mem 0x0000000070000000-0x0000000077ffffff]
```


