SIM=iverilog -I rtl/verilog

.PHONY: test fetch xrs alu decode

test: fetch xrs alu decode polaris

fetch:
	$(SIM) -Wall bench/verilog/fetch.v rtl/verilog/fetch.v
	vvp -n a.out

xrs:
	$(SIM) -Wall bench/verilog/xrs.v rtl/verilog/xrs.v
	vvp -n a.out

alu:
	$(SIM) -Wall bench/verilog/alu.v rtl/verilog/alu.v
	vvp -n a.out

decode:
	$(SIM) -Wall bench/verilog/decode.v rtl/verilog/decode.v
	vvp -n a.out

polaris:
	$(SIM) -Wall bench/verilog/polaris.v rtl/verilog/polaris.v
	vvp -n a.out
