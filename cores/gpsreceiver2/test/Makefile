SOURCES=tb_gpsreceiver.v $(wildcard ../rtl/*.v) RAMB16BWER.v

all: cversim

isim: tb_gpsreceiver
	./tb_gpsreceiver

cversim: $(SOURCES)
	cver $(SOURCES)

clean:
	rm -f tb_gpsreceiver verilog.log gpsreceiver.vcd *.vcd

tb_gpsreceiver: $(SOURCES)
	iverilog -o tb_gpsreceiver $(SOURCES)

.PHONY: clean sim cversim
