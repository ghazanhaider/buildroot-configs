#!/bin/bash

if [[ -e $1 && -d $2]]
then
	cpp -nostdinc -I $2/include -I $2/arch -I $2/arch/arm/boot/dts/ -undef -x assembler-with-cpp  $1 $1.preprocessed
	dtc -I dts -O dtb $1.preprocessed -o $1.dtb

	echo "Output file: $1.dtb"
else
	echo "Usage: dtscompile.sh <file.dts> <path_to_linux-x.y.zz>"
	echo " The first argument must be a file, the second a directory"
	echo " The binaries cpp and dtc must be in path"
fi



# Old notes, working commands

#  dtscompile.sh at91sam9261ek/at91sam9261ek.dts /root/buildroot-2023.02.1/output/build/linux-6.1.26

#cpp -nostdinc -I /root/buildroot-2023.02.1/output/build/linux-6.1.26/include -I /root/buildroot-2023.02.1/output/build/linux-6.1.26/arch -I /root/buildroot-2023.02.1/output/build/linux-6.1.26/arch/arm/boot/dts/ -undef -x assembler-with-cpp  fixedv2.dts fixedv2.dts.preprocessed


#cpp -nostdinc -I /root/buildroot/output/build/linux-6.3.8/include -I /root/buildroot/output/build/linux-6.3.8/arch -I /root/buildroot/output/build/linux-6.3.8/arch/arm/boot/dts/ -undef -x assembler-with-cpp  at91sam9261ek/at91sam9261ek.dts at91sam9261ek/at91sam9261ek.dts.prep

#cpp -nostdinc -I /root/buildroot/output/build/linux-6.3.8/include -I /root/buildroot/output/build/linux-6.3.8/arch -I /root/buildroot/output/build/linux-6.3.8/arch/arm/boot/dts/ -undef -x assembler-with-cpp  at91sam9260ek/at91sam9260ek.dts at91sam9260ek/at91sam9260ek.dts.prep

#dtc -I dts -O dtb at91sam9260ek/at91sam9260ek.dts.prep -o at91sam9260ek/at91sam9260ek.dtb

#dtc -I dts -O dtb at91sam9261ek/at91sam9261ek.dts.prep -o at91sam9261ek/at91sam9261ek.dtb
