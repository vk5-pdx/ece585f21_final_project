/****************************************************************
 * queue_tb.sv - testbench for queue
 *
 * Author        : Viraj Khatri (vk5@pdx.edu)
 * Last Modified : 16th November, 2021
 *
 * Description   :
 * -----------
 * testbench for queue
 ****************************************************************/

import global_defs::*;

module queue_tb;

// global connections
logic clk, rst_n;

/**********
 * parser *
 **********/
// connections
int_t               queue_time;      // display what time is queue currently at
logic               queue_full;      // flag for queue being full
logic               pending_request; // flag to denote if currently read trace-line
                                     // is not dealt with yet

parser_out_struct_t parser_out;

parser_states_t     parser_state;

// instantiation
parser parser_inst(.clk, .rst_n,
                   .pending_request,
                   .queue_time,
                   .queue_full,
						 .out(parser_out),
						 .state(parser_state)
);


/*********
 * queue *
 *********/
// connections
parser_out_struct_t queue_out;             // output to next module (memory controller / DRAM?)
parser_out_struct_t queue[$:QUEUE_SIZE-1]; // queue to store many memory requests
age_counter_t       age[$:QUEUE_SIZE-1];

// instantiation
queue queue_inst(.clk, .rst_n,
                 .in(parser_out),
                 .pending_request,
                 .queue_full,
                 .out(queue_out),
                 .queue,
                 .age,
                 .queue_time
);



/*************
/* Clock gen *
 *************/
initial begin
	clk = 0;
	forever #5 clk = ~clk;
end

initial begin
	$display("/************************************* ");
	$display(" * 10 simulation ticks = 1 CPU clock * ");
	$display(" *************************************/");
	rst_n = 1'b0;
	#10;
	rst_n = 1'b1;
	#600000;
	$stop;
end

endmodule : queue_tb
