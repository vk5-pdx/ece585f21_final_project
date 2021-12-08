# Report for ECE 585 Fall 2021 Group 12 Project

## Introduction

In this project, we have designed, and performed verification of a memory controller with PC4-25600 DIMM serving the last level cache of a four core 3.2 GHz processor employing a single memory channel. The capacity of the dimm is 8GB and the page size is 2KB. The design follows the timing constraints displayed below.

The addressed is mapped as depicted in the diagram below -
![memory mapping diagram](images/memory_address_map.jpg)

This makes the bank hierarchy that we have chosen as shown below -
![bank_breakdown.jpg](images/bank_breakdown.jpg)

## DESIGN OVERVIEW

The design starts from the parser. The parser opens the input trace file and parses the requests to the queue module (controller module). The parser and the queue module share flags back and forth. Based upon the pending request and the queue_full signal the FSM in the parser decides to parse the request to the queue module.\

In the queue module, the request is entered in the queue and the decision is made to insert a request into the queue based-on queue size. After entering the queue before writing the output dram trace file, based on the bank group, bank, row, and column status the decision is made whether to pre-charge or activate or read. In the code there are 2 functions - one converts the queue commands to DRAM operation sequences, the other one updates the bank status and decides which command to output (dram commands). Whichever commands are decided by the previous statement to be outputted to the dram file is done at the dram clock speeds and by an independent block of code written as a function.
## VERIFICATION

For all the debug statements used in the verification can be turned on/off before starting the simulation. For all individual module verification, we created input traces for general cases and corner cases and verified them.\
### Parser Verification
We verified the parser by opening a trace file and printing the requests in the transcript and compared the transcript with the trace for proper parsing.
### Queue Verification
To test the working of Queue we parsed the requests from the parser to the queue module and printed the queue status like whether something was inserted in the queue or popped off the queue and we also printed the queue elements for every clock edge on the transcript and compared with the timing given in the trace file of each request.
### Memory Controller verification
We have made some test case files for checking individual cases like when no pre charge is needed or TCCD_S or TCCD_L occurs. For debugging we printed queue status, bank status, open row, open column, and others.
## CHALLENGES
* One of the scenarios was when multiple requests arrive at the same time from multiple cores i.e. 4 cores. This has been resolved in the order in which it is provided in the input trace file.
* Trace file had to be perfectly formatted with a 33-bit input which is pretty rare to find, so we implemented a padding system to eliminate any ‘x’ we get from shorter addresses - 0x0001 instead of 0x000000001, because SystemVerilog is x pessimistic.
* Conceptualizing and implementing a complex system in parallely run always_ff blocks caused delay issues where the block that should only be processed after the decisions from another block was happening simultaneously, which causes these blocks to be delayed by 1 clock cycle, and using 2-3 such blocks delays full output by a couple of clock cycles.


## TEST SCENARIOS

| Trace file name | Description |
|:---:|:---|
| continuous_repetition | Multiple instruction at the same time |
| cp3_trace | Repetition and time skip |
| trace_schedule_try | Checking for in-order scheduling |
| normal_trace | Basic trace instructions |
| queue_full | Checking for queue full condition |
| queue_overload_with_age_pop | Checking whether requests pops properly  |
| queue_overload_with_out_of_order_with_age_pop | Checking whether requests pops properly in scheduling |
| trace_1 - trace_7 | Different combinations of bank group, bank |
| t_ccd_rrd | Checking for rrd and ccd  time delay |


## CONCLUSION
In conclusion, we were able to understand and verify the entire design, we used the bottom-up verification strategy. Initially verified parser, then queue and finally the memory controller. All in all, it is a good learning experience for everyone on the team.

## REFERENCES
* ECE – 585 Lecture notes
* 4Gb_DDR4_DRAM.pdf

