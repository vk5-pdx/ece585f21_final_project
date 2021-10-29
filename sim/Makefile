# makefile for standard compilation
sim_dir = $(shell pwd)

parser:
	vlib work
	vlog $(sim_dir)/../hdl/global_defs.sv $(sim_dir)/../hdl/parser.sv $(sim_dir)/../hdl/parser_tb.sv
	vsim -c work.parser_tb

