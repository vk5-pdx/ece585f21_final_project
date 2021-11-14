/****************************************************************
 * parser_tb.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 11th November, 2021
 *
 * Description   :
 * -----------
 * Testbench for checkpoint 3
 ****************************************************************/
import global_defs::*;
module parser_tb();

//naming variables for the design
logic CPU_clock, rst_n;                   // as name states
parser_out_struct parser_output;          // connects parser to fifo queue
parser_out_struct fifo_input,fifo_output; // input output connections of fifo
logic full,empty,insert_flag,exit_flag;   // status signals for fifo
parser_out_struct queue[$ : DEPTH-1];     // connection for the actual queue storage
parser_out_struct buffer_q [$];
parser parser0 (.*);
fifo fifo0 (.*, .fifo_input(parser_output));

initial begin          //generating clock
	CPU_clock = 0;
	forever #5 CPU_clock = ~CPU_clock;
end

initial begin
	$display("10 simulation ticks = 1 clock cycle");
	rst_n = 1'b0;
	#10;
	rst_n = 1'b1;
	#10000;
	$finish;
end

//printing statemnets for parser
`ifdef parserdebug
	always@(posedge CPU_clock) begin
		if ($test$plusargs("debug")) $strobe ("%d : CPU_Clock = %d\tMemCode = %d\tAddress = %h\top_ready_s = %b",$time,parser_output.CPU_clock_count,parser_output.opcode,parser_output.address,parser_output.op_ready_s); //monitors output when the address or opcode changes
	end
	`endif

//printing statemnets for queue
`ifdef queuedebug
	always@(posedge CPU_clock) begin
			if ($test$plusargs("debug")) $strobe("%t : queue:%p",$time,queue);
	end
`endif

//printing statemnets for buffer queue
`ifdef queuedebug_temp
	always@(posedge CPU_clock) begin
		if ($test$plusargs("debug")) $strobe("%t : Queue:%p",$time,buffer_q );
	end
`endif

endmodule
