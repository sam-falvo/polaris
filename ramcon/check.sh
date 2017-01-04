#!/bin/bash

yosys -p 'read_verilog -formal kcp5300x_tb.v' \
      -p 'prep -top kcp5300x_tb -nordff'      \
      -p 'write_smt2 kcp5300x.smt2'        && \
yosys-smtbmc kcp5300x.smt2                 && \
yosys-smtbmc -i kcp5300x.smt2

