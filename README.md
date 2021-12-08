# ECE 585 Fall 2021 Final Project

output dram command trace file - `sim/dram`

## build instructions

```
make       # just output to sim/dram with minimal prints
make debug # output to sim/dram and enable all debugging prints
make dram  # output to sim/dram and enable dram prints
make queue # output to sim/dram and enable queue prints
```

## custom tracefile

for Makefile builds, the `traces/trace.txt` symbolic link is used as the input tracefile.\
this behavior can be changed in 2 ways -

### changing the symbolic link

* remove `traces/trace.txt` symbolic link
* make a new symbolic link
```
cd traces
ln -s <full_path_to_custom_trace_file> trace.txt
cd ../sim
make
```

### manually passing as plusarg to vsim command

```
cd sim
vlib work
vlog ../hdl/global_defs.sv # this is done to ensure package is imported properly
vlog ../hdl/*.sv
vsim -c -do "run all ; q" +nowarn3691 work.queue_tb +tracefile=<full_path_to_custom_tracefile>
```
