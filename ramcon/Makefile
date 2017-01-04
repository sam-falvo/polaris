SIM=iverilog -I rtl/verilog

.PHONY: test ramcon

test: ramcon

rtl/verilog/kseq.v: rtl/SMG/kseq.smg
	smg.shen rtl/SMG/kseq.smg >rtl/verilog/kseq.v

ramcon: bench/verilog/ramcon.v rtl/verilog/ramcon.v rtl/verilog/kseq.v
	$(SIM) -Wall bench/verilog/ramcon.v rtl/verilog/ramcon.v rtl/verilog/kseq.v
	vvp -n a.out
