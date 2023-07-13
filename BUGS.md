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

