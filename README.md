# Legacy AT91 board configs for Buildroot

## Overview 

I have the following boards that I wanted to use with the latest Linux kernel and new-ish uCLibc, U-Boot and AT91Bootstrap:

- AT91SAM9260-EK
- AT91SAM9261-EK
- AT91SAM9G45-EKES
- SAMA5G3-XPLND
- SAM9X60-EK

The first three boards are no longer 'supported' by current U-Boot versions and their DTS is outdated even within the Linux kernel and do not work out of the box.

This repository is based on Buildroot version 2023.05.x and U-Boot 2023-07-02

The folders are of type BuildRoot external, and the first three boards have common config. Only their hostnames, DTS files and AT91Bootstrap3 config are different.

I try to put bootloaders and kernel exclusively on either Dataflash or NAND flash, but for some boards (9260-EK, older revs) we have to use both.

I put the root filesystem on SD cards. I flashed them as-is to the SD card (not to a specific partition, just faster workflow). This means to Linux root must be mmcblk0. In the future I'll try to have a small FAT partition on the SD card with U-Boot.bin and uImage kernel files there and second partition of rootfs.

I have not had any success putting the rootfs on nandflash on any of these boards for some reason, except for disabling ECC fully (bad idea).



## Steps to build

- Clone Buildroot:
```
git clone git@github.com:buildroot/buildroot.git
```

- Clone this repository:
```
git clone git@github.com:ghazanhaider/buildroot-configs.git
```
(We will assume I've irresponsibly cloned it into /root so I'll use this path, but you can use a better folder with the next command)

- Create an output folder:
```
mkdir /926X
```

- Build the config/makefiles for a board (at91sam9260-ek board as an example):
```
make O=/926X BR2_EXTERNAL=/root/buildroot-configs/926x/
```

- Inspect files as necessary before starting the build:
```
make O=/926X nconfig
cp ../buildroot-configs/at91sam9260ek/br-config /926X/.config
make O=/926X nconfig
make O=/926X at91boostrap3-menuconfig
cp ../buildroot-configs/926x/myat91sam9260ek/at91bootstrap3-config /9260/build/at91bootstrap3-v3.10.3/.config
make O=/926X at91boostrap3-menuconfig
cp myat91sam9260ek/myat91sam9260ek.dts /9260/build/linux-6.4.5/arch/arm/boot/dts/working.dts
make O=/926X uboot-nconfig
make O=/926X linux-nconfig
make O=/926X busybox-nconfig
make O=/926X uclibc-nconfig
```

- Build away, this should take more than half an hour:
```
make O=/926X all
```

- Find files under the `/926X/images` folder:
uImage
u-boot.bin
<boardname>.dtb
rootfs.**
at91bootstrap3.bin

- Assuming you have SAM-BA 2.18 installed and want to flash your board using a J-Link JTAG adapter (on Windows):
```
cd 'C:/Program Files (x86)/Atmel/sam-ba_2.18'
.\sam-ba.exe \jlink\ARM0 AT91SAM9260-EK
```
- SAM-BA will also upload using the device USB port but the board then has to be in Rom-Monitor mode.
- The command for SAM-BA through USB is something like `.\sam-ba.exe \USBserial\COM04 AT91SAM9260-EK`


- SAM-BA has a GUI menu.
- To flash anything to the dataflash, pick Enable Dataflash bus/chip select and Execute. This enables the dataflash before any upload.
- To flash anything to the nandflash, pick Enable Nandflash and Execute. This enables the nandflash before any upload.
- Follow the memory map to see where each file needs to get flashed:
```
Dataflash:
at91bootstrap.bin	Address: 0x0
u-boot.bin		Address: 0x40000

Nandflash:
<board>.dtb		Address: 0x180000
uImage			Address: 0x200000
u-boot-env.bin		Address: 0x140000
u-boot-env-r.bin	Address: 0x100000
```

- Boot the board into U-Boot.

- The *bootcmd* variable is a single line and needs to have the following bits:
`mw.l 0xFFFFFD08 0xA5000100; mw.l 0xFFFFFD00 0xA5000008;`
This is a way to lower NRST without resetting the whole board.
Boards with the DM9161 ethernet PHY needs this and the phy-reset code does not work in At91Bootstrap OR U-Boot.
It resets a few other chips too like the Dataflash and audio PCM.
You might not need it for other boards

`nand read 0x22000000 0x200000 0x6fffff;nand read 0x21000000 0x180000 0x8000;fdt addr 0x21000000;`
Copy the Linux kernel and dtb file to the expected locations in ram.
The kernel keeps growing in size, 0x6fffff size works for me for now but I've once had to increase it further.

`bootm 0x22000000 - 0x21000000`
Boot the Linux kernel and dtb file locations in ram

- The *bootargs* variable is just the kernel args. Important bits are:
`console=ttyS0,115200`
This should be the default but might as well hardcode it to make sure you always see it booting.
The first serial port on AT91 boards is the DBGU serial port.
You can output console to multiple ports.

`root=mtd6 rootfstype=jffs2 rw rootwait`
For JFFS on NAND partition 6. Only works with ECC disabled for me.

`ubi.mtd=6 root=/dev/mmcblk0 rootfstype=ext4 ro rootwait`
Should boot ubifs. This has never worked for me. I gave up on UBIFS for now.

`root=/dev/mmcblk0 rootfstype=ext4 ro rootwait`
SD card boot with the rootfs.ext4 image copied to the raw device (no partition table).
It just works. Eventually I should use a better filesystem for wear leveling. For now I'll just use more expensive SD cards.
Use only 32GB max cards because that's the SDHC limit.
Boards like the 9260/9261 also top out around 20-30MBps read or write, so faster cards won't help speeds.

`root=/dev/sda rootfstype=ext4 ro rootwait`
USB stick boot. Also just works but takes up a USB port.
This is good for trying out root images of other distributions (debian, slackware etc) while still keeping the local SD image.


## Older notes (should no longer work):
## AT91SAM9260-EK

- Git clone buildroot (2023.05 was used here)
- br-config becomes the .config at the root of this buildroot
- linux-config becomes output/build/linux-6.3.8/.config
- uboot-config becomes output/build/uboot-2022.04/.config
- uclibc-config becomes output/build/uclibc-1.0.43/.config

- Also git clone At91Bootstrap3 and compile separately, the one that comes with buildroot fails

### Flash details

- K9F2G08U0A Samsung 256Mx8
- Page: 2k + 64 (0x800)
- Block Erase: 128k + 4k (0x20000)
- ECC 1 bit/512 byte?
- No sub page
- UBI LEB size: 126976 / 1f000


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
- Datasheet says: "Interfacing 24 bit-per-pixel TFTs panel prevents using the SSC0 and the chip select line 0 of the SPI1"
- FB must be disabled to allow SPI0 (/ahb/fb node removed from dts, not just disabled)
- Audio DAC CS is PA29 instead of PA6 which is used for CS for MMC
- With FB disabled, Dataflash, touchscreen work but dac still doesnt show up.
- SPI CS1 conflicts with Button BP3 and is not used on the board.
- SPI1 (CS2 CS3 MOSI) conflicts with both NAND and Audio DAC. Unused.
- /ahb/i2c and /ahb/ssc must be enabled and they do work.



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


## SAM9x60-EK

Notes:
- Stock uBoot does not work for this board. Neither serial nor the timer works and throws continuous errors.
- There's a fork of uBoot with updated drivers that works: https://github.com/linux4sam/u-boot-at91/tree/u-boot-2022.01-at91
- I simply used Microchip's demo package, the uBoot in it: linux4sam-poky-sam9x60ek-headless-2023.04
`https://www.linux4sam.org/bin/view/Linux4SAM/DemoArchive`
- uBoot is bigger than 512KiB here in most cases, change the layout for uboot to be 768KiB and move the env slot, keep kernel at 0x200000
- Use sam-ba 3.x. The workflow is very different from sam-ba 2.18. I modified a QML file to point to my files (I did not use an itb file)
- Current measure device PAC1934 driver is not mainlined, it is in the linux4sam kernel:
`https://github.com/linux4microchip/linux/blob/linux-6.1-mchp/drivers/iio/adc/pac1934.c`
- However you can still read numbers from `/sys/bus/i2c/devices/1-0017/of_node/status`
- PAC1710 has no driver in either kernels but its data can also be fetched through the i2c bus.
- All other drivers are mainlined and work (LCD not personally tested)
- I've not disabled the Watchdog in this bootloader, which means u-boot must boot the kernel in just a few seconds.
- The kernel runs a thread *watchdogd* which keeps the watchdog alive, the userspace daemon and /etc/watchdog.conf is not configured
- Since u-boot is from Microchip's demo, it tries to boot the kernel through *bootz* which fails, we need *bootm*. So bootcmd and bootargs are both reconfigured in u-boot-env.bin.
- The args are in ubootenv.txt
- Run this command to produce the u-boot-env.bin image (and copy it to the sam-ba folder keeping this name so that the qml script can find it)
`mkenvimage -r -s 0x20000 -o sam9x60ek/u-boot-env.bin sam9x60ek/bootenv.txt`
-- TODO: Compile the Microchip forked u-boot with our config.

### Flash details
- The NAND chip has the following features:
-- 256KiB block size (also erase block size) (+14K spare)
-- 4KiB page size (+224 bytes spare/OOB)
-- No subpage feature, use 4KiB
-- Sector size: 512
-- Device size: 2048 blocks

- For PMECC this translates to:
-- ECC bits: 8
-- ECC offset: 120
-- ECC size: 104 (fits in the 224 byte OOB space)

- For UBIFS:
-- Physical Eraseblock Size: 0x40000 (256KiB)
-- Subpage size (Keep at 0 for UBI to make it the same as page size)
-- UBIFS Logical Eraseblock Size: 0x3E000 (248KiB, 8KiB is filesystem overhead)
-- UBIFS Minimum IO unit: 0x1000 (4096 is page size)
-- Runtime compression: lxo (can be anything the kernel supports)

- The kernel boot commandline that works with the above (put it in u-boot bootcmd default):
`console=ttyS0,115200 earlyprintk mtdparts=atmel_nand:256k(bootstrap)ro,768k(uboot)ro,256k(env_redundant),256k(env),512k(dtb),6M(kernel)ro,-(rootfs) ubi.mtd=12 root=ubi0:rootfs rootfstype=ubifs rw rootwait`

### Flashing images using SAM-BA

- sam-ba.exe must be run in the sam-ba folder, just adding the folder as a path does not work because it fetches modules from subfolders
- Run: `sam-ba.exe -x ./flash.qml` (using my sample flash.qml)
- The flash.qml file uses *SerialConnection* for USB uploading which is much faster than the J-Link CDC port. For this you must plug a micro-USB cable into USBA/J7 (and no need for a power cord, the board gets power from this micro-USB cable.
- For DBGU output, you'll need to switch back to the J-Link/J22 micro-USB cable, and add a 5V power to the board as well.
- If you want to just upload code through the J-Link cable (slower) and not switch back n forth, change *SerialConnection* to *JLinkConnection* in the flash.qml file and run it the same way.
- The files to upload (uImage, u-boot.bin, rootfs.ubi, u-boot-env.bin, at91bootstrap.bin) must be copied into the sam-ba folder because paths somehow fail for me in the qml file.
