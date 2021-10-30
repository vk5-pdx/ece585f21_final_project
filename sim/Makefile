# makefile for standard compilation
sim_dir = $(shell pwd)

parser:
	vlib work
	vlog $(sim_dir)/../hdl/global_defs.sv $(sim_dir)/../hdl/parser.sv $(sim_dir)/../hdl/parser_tb.sv

parser_wave:
	vsim -voptargs=+acc work.parser_tb
	#add wave -position insertpoint sim:/parser_tb/dut/*

parser_term:
	vsim -voptargs=+acc -c work.parser_tb
