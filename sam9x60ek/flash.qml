import SAMBA 3.7
import SAMBA.Connection.JLink 3.7
import SAMBA.Connection.Serial 3.7
import SAMBA.Device.SAM9X60 3.7


// This file was shamelessly copied from the linux4sam demo.
// It was referencing SAMBA 3.5, I changed filenames and 3.5 to 3.7 above.
// Both Serial and JLink modules are imported so that switching between them is easy.
// Just replace SerialConnection with JLinkConnection and keep the usb cord in the jlink port.
// JLink is MUCH slower but doesnt require switching usb back n forth

SerialConnection {

	device: SAM9X60EK {
		config {
			nandflash {
				header: 0xc1e04e07
			}
		}
	}

	function checkDeviceID() {
		// read CHIPID_CIDR register
		var cidr = readu32(0xfffff240)
		if (cidr == 0x819b35a0) {
			throw new Error("Chip ID (CIDR = " + Utils.hex(cidr) + ")" +
				" tells that this is an Engineering Sample: not supported")
		} else {
			print("Chip ID: CIDR/EXID = " + Utils.hex(cidr) +
				"/" + Utils.hex(readu32(0xfffff244)))
		}
	}

	function getEraseSize(size) {
		/* get smallest erase block size supported by applet */
		var eraseSize
		for (var i = 0; i <= 32; i++) {
			eraseSize = 1 << i
			if ((applet.eraseSupport & eraseSize) !== 0)
				break;
		}
		eraseSize *= applet.pageSize

		/* round up file size to erase block size */
		return (size + eraseSize - 1) & ~(eraseSize - 1)
	}

	function eraseWrite(offset, filename, bootfile) {
		/* get file size */
		var file = File.open(filename, false)
		var size = file.size()
		file.close()

		applet.erase(offset, getEraseSize(size))
		applet.write(offset, filename, bootfile)
	}
	onConnectionOpened: {

	
		var mydtb = "base_fdt.dtb" // Working dbt copied from linux4sam demo
		var mykernel = "uImage" // Legacy uImage kernel format with no dtb inserted
		var myrootfs = "rootfs.ubi" // 512MB UBIFS inside UBI
		var myboot = "at91bootstrap.bin" // Runs u-boot, doesnt disable watchdog
		var myubootenv = "u-boot-env.bin" // Update bootcmd and bootargs vars
		//var myuboot = "u-boot.bin" // Stock u-boot fails
		var myuboot = "workingu-boot.bin" // Atmel fork u-boot works


		// check that chip revision is supported by Linux4SAM delivery
		checkDeviceID()

		// initialize Low-Level applet
		print("-I- === Initilize low level (system clocks) ===")
		initializeApplet("lowlevel")

		// intialize extram applet (needed for sam9)
		print("-I- === Initialize extram ===")
		initializeApplet("extram")

		print("-I- === Initialize nandflash access ===")
		initializeApplet("nandflash")
		// erase then write files
		print("-I- === Load AT91Bootstrap ===")
		eraseWrite(0x00000000, myboot, true)

		print("-I- === Load u-boot environment ===")
		//erase redundant env to be in a clean and known state
		applet.erase(0x00100000, getEraseSize(0x20000))
		eraseWrite(0x00140000, myubootenv)

		print("-I- === Load u-boot ===")
		eraseWrite(0x00040000, myuboot)

		print("-I- === Load DTB image ===")
		eraseWrite(0x00180000, mydtb)

		print("-I- === Load kernel image ===")
		eraseWrite(0x00200000, mykernel)

		print("-I- === Load root file-system image ===")
		applet.erase(0x00800000, applet.memorySize - 0x00800000)
		applet.write(0x00800000, myrootfs)

		print("-I- === Done. ===")
	}
}
