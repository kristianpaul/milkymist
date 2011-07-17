SOURCES=tb_namuru.v $(wildcard ../rtl/*.v)

all: cversim

isim: tb_namuru
	./tb_namuru

cversim: $(SOURCES)
	cver $(SOURCES)

clean:
	rm -f tb_namuru verilog.log *.vcd

tb_namuru: $(SOURCES)
	iverilog -o tb_namuru $(SOURCES)

.PHONY: clean sim cversim
