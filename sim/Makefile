# makefile for standard compilation
.PHONY : VSIM VLOG VLIB parser all clean

sim_dir := $(shell pwd)
source_dir := $(shell pwd)/../hdl/
sv_files := $(shell find $(source_dir) -name '*.sv')

trace_file = "$(sim_dir)/../trace_file.txt"
top_module = "parser_tb"
sim_opts := \
	+debug \
	+tracefile=$(trace_file)

VLIB:
	cd $(sim_dir)
	vlib work

VLOG: VLIB
	cd $(sim_dir)
	vlog $(sv_files)

all: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all" +nowarn3691 \
		work.$(top_module) \
		$(sim_opts)

parser: VLOG
	cd $(sim_dir)
		vsim -c -do "run -all" +nowarn3691 \
		work.parser_tb \
		$(sim_opts)

clean:
	echo "why?"
