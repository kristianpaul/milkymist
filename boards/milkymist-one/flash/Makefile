MMDIR?=../../..

TARGETS=standby.fpg soc-rescue.fpg bios-rescue.bin splash-rescue.raw soc.fpg gps.bin bios.bin splash.raw
SERIAL?=/dev/ttyUSB0

all: $(TARGETS)
clean:
	rm -f $(TARGETS) boot.bit

standby.fpg:
	$(MAKE) -C $(MMDIR)/tools
	$(MAKE) -C $(MMDIR)/boards/milkymist-one/standby
	cp $(MMDIR)/boards/milkymist-one/standby/build/standby.fpg .

#soc-rescue.fpg:
#	$(MAKE) -C $(MMDIR)/tools
#	$(MAKE) -C $(MMDIR)/boards/milkymist-one/synthesis -f Makefile.xst RESCUE=1
#	cp $(MMDIR)/boards/milkymist-one/synthesis/build-rescue/system.fpg soc-rescue.fpg

bios-rescue.bin:
	$(MAKE) -C $(MMDIR)/tools
	$(MAKE) -C $(MMDIR)/software/libhpdmc
	$(MAKE) -C $(MMDIR)/software/libbase
	$(MAKE) -C $(MMDIR)/software/libhal
	$(MAKE) -C $(MMDIR)/software/libnet
	$(MAKE) -C $(MMDIR)/software/bios
	$(MAKE) -C $(MMDIR)/software/gps
	cp $(MMDIR)/software/bios/bios-rescue.bin .

splash-rescue.raw: splash-rescue.png
	$(MAKE) -C $(MMDIR)/tools
	$(MMDIR)/tools/makeraw splash-rescue.png

soc.fpg:
	$(MAKE) -C $(MMDIR)/tools
	$(MAKE) -C $(MMDIR)/boards/milkymist-one/synthesis -f Makefile.xst
	cp $(MMDIR)/boards/milkymist-one/synthesis/build/system.fpg soc.fpg

bios.bin:
	$(MAKE) -C $(MMDIR)/tools
	$(MAKE) -C $(MMDIR)/software/libhpdmc
	$(MAKE) -C $(MMDIR)/software/libbase
	$(MAKE) -C $(MMDIR)/software/libhal
	$(MAKE) -C $(MMDIR)/software/libnet
	$(MAKE) -C $(MMDIR)/software/bios
	cp $(MMDIR)/software/bios/bios.bin .
	
gps.bin:
	$(MAKE) -C $(MMDIR)/tools
	$(MAKE) -C $(MMDIR)/software/libhpdmc
	$(MAKE) -C $(MMDIR)/software/libbase
	$(MAKE) -C $(MMDIR)/software/libhal
	$(MAKE) -C $(MMDIR)/software/libnet
	$(MAKE) -C $(MMDIR)/software/gps
	cp $(MMDIR)/software/gps/gps.bin .

splash.raw: splash.png
	$(MAKE) -C $(MMDIR)/tools
	$(MMDIR)/tools/makeraw splash.png

flash: all
	sudo jtag -n flashall.batch

connect:
	stty -F $(SERIAL) raw 115200
	while : ; do cat $(SERIAL) ; done & cat > $(SERIAL)

boot:           boot.jtag boot.bit
	        jtag -q boot.jtag

standby:        standby.jtag
	        jtag -q standby.jtag

boot.bit:       mkboot
	        ./mkboot >$@ || { rm -rf $@; exit 1; }


.PHONY: flash clean connect boot standby clean
