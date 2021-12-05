# makefile for standard compilation
.PHONY : VSIM VLOG VLIB parser all clean

sim_dir := $(shell pwd)
source_dir := $(shell pwd)/../hdl/
sv_files := $(shell find $(source_dir) -name '*.sv')

trace_file = "$(sim_dir)/../traces/trace.txt"

top_module = "queue_tb"
sim_opts := \
	+debug_dram \
	+tracefile=$(trace_file)


VLIB:
	cd $(sim_dir)
	vlib work

VLOG: VLIB
	cd $(sim_dir)
	vlog $(sv_files)

all: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		$(sim_opts)

parser: VLOG
	cd $(sim_dir)
		vsim -c -do "run -all ; q" +nowarn3691 \
		work.parser_tb

queue: VLOG
	cd $(sim_dir)
		vsim -c -do "run -all ; q" +nowarn3691 \
		work.queue_tb \
		+debug_queue

debug: VLOG
	cd $(sim_dir)
	vsim -c -do "run -all ; q" +nowarn3691 \
		work.$(top_module) \
		$(sim_opts) +per_no_op +debug_queue +per_clk

gui: VLOG
	cd $(sim_dir)
	vsim -voptargs=+acc -do "run -all" +nowarn3691 \ # TODO : add waveform addition commands before "run -all" to display correctly
		work.$(top_module) \
		$(sim_opts)

clean:
	echo "why?"
