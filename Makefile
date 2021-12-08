# makefile for standard compilation
.PHONY : all clean VLOG

sim_dir := $(shell pwd)/sim/
source_dir := $(shell pwd)/hdl/
traces_dir := $(shell pwd)/traces/
out_dir := $(shell pwd)/outs/
sv_files := $(shell find $(source_dir) -name '*.sv')

top_module = "queue_tb"

tracefile = $(traces_dir)/our_tracefiles/trace.txt
outfile = $(out_dir)/dram
plus_args := +tracefile=$(tracefile) +outfile=$(outfile)

silent: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		$(plus_args)

VLIB:
	mkdir -p $(sim_dir)
	cd $(sim_dir)
	vlib work

VLOG: VLIB
	cd $(sim_dir)
	vlog hdl/global_defs.sv
	vlog $(sv_files)

all: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		+debug_dram +debug_queue +per_clk \
		$(plus_args)

queue: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		+debug_queue \
		$(plus_args)

dram: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		+debug_dram \
		$(plus_args)

clean:
	echo "why?"
