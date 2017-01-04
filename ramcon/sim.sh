#!/bin/bash

iverilog kcp5300x_tb.v kcp5300x.v kseq.v && \
 vvp -n a.out

