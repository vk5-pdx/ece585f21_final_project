# ECE 585 Fall 2021 Final Project Group 12

## some things

* [github repo](https://github.com/vtkhatri/ece585f21_final_project)
* tracefiles from presentation - `traces/presentation_tracefiles/t*.trace`
  * output files for these stored in - `outs/t*.out`
* group tracefiles or checking - `traces/our_tracefiles/*.txt`

---

To execute all presentation tracefiles use single line command -

```
for i in {0..13}; do make silent tracefile=$PWD/traces/presentation_tracefiles/t$i.trace outfile=$PWD/outs/t$i.out; done
```

## build instructions

```
make silent tracefile=<trace_file> outfile=<out_file>
make all tracefile=<trace_file> outfile=<out_file>    # to get all debug prints, with +per_clk
make dram tracefile=<trace_file> outfile=<out_file>   # to get dram debug prints only
make queue tracefile=<trace_file> outfile=<out_file>  # to get queue debug prints only
```
### manually passing as plusarg to vsim command

```
cd sim
vlib work
vlog ../hdl/global_defs.sv # this is done to ensure package is imported properly
vlog ../hdl/*.sv
vsim -c -do "run all ; q" +nowarn3691 work.queue_tb +tracefile=<trace_file> +outfile=<out_file>
```

## report

report is present in `docs/report.md`
