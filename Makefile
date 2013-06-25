all: ep 

ep: ep.o 
	@echo Linking ep.o
	arm-elf-ld -Ttext=0x0 ep.o -o ep

ep.o: ep.s
	@echo Assembling ep.s
	arm-elf-as -g ep.s -o ep.o

# %.o : %.s
#	@echo Assembling $*.s
#	arm-elf-as -g $< -o $*.o

# dump: helloworld
#	arm-elf-objdump -S helloworld

# readelf: helloworld
#	arm-elf-readelf -a helloworld

# gdbtarget: helloworld
#	arm-sim --load=helloworld -debug-core -enable-gdb

# gdbhost: helloworld
#	armv5e-elf-gdb helloworld

clean:
	-rm ep ep.o
