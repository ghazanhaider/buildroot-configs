# Bugs


`drivers/net/dm9000x.c:98:27: error: field ‘netdev’ has incomplete type`

Add this to uboot's .config:
`CONFIG_PHY_DAVICOM=y`

And remove this (counterintuitive):
`CONFIG_DM_ETH`


`/root/buildroot/output/build/uboot-2022.04/cmd/mtdparts.c:1740: undefined reference to `board_mtdparts_default'`

Remove mtdparts or part command:
`CONFIG_CMD_PART`
`CONFIG_CMD_MTDPARTS`
`CONFIG_CMD_MTD`


```
In file included from ./arch/arm/include/asm/arch/gpio.h:11,
                 from ./arch/arm/include/asm/gpio.h:2,
                 from drivers/mtd/nand/raw/atmel_nand.c:15:
drivers/mtd/nand/raw/atmel_nand.c: In function ‘atmel_nand_calculate’:
drivers/mtd/nand/raw/atmel_nand.c:1011:31: error: ‘ATMEL_BASE_ECC’ undeclared (first use in this function); did you mean ‘ATMEL_BASE_ADC’?
 1011 |         ecc_value = ecc_readl(ATMEL_BASE_ECC, PR);
```


Boards like at91sam9260EK have a phy that requires an NRST reset from the reset controller before they come alive, neither the Linux kernel nor uboot/at91bootstrap does this reset.

In uboot, this command can do the reset before loading the kernel:
`mw.l 0xFFFFFD08 0xA5000100; mw.l 0xFFFFFD00 0xA5000008; mii info`

Before reset, the phy shows up at 0x1f, after reset, 0x1c (sometimes 0x4,0x1c,0x14)

At91Bootstrap3+ Can do this reset but the code is broken. Here's how to fix it (tested on 3.10.3):

- In include/arch/at91_rstc.h, replace:
`#define AT91C_RSTC_ERSTL(x)     ((x) & AT91C_RSTC_ERSTL_MASK << 8)`
with..
`#define AT91C_RSTC_ERSTL(x)     ((x << 8) & AT91C_RSTC_ERSTL_MASK)`

- In driver/pmc/clk-common.c, replace:
`#ifdef CONFIG_SAMA5D3X_CMP`
with..
`#if defined(CONFIG_SAMA5D3X_CMP) || defined(CONFIG_AT91SAM9260EK)`

They seemed to have added the reset code for one board but not the other, and the mask placement is incorrect.

If you're not sure, compare the values and registers with the above uboot command. 



