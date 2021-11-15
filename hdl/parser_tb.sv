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
	parameter DEPTH = 16;
	parameter ADDRESS_WIDTH = 32;
	logic CPU_clock, rst_n;
	parser_out_struct parser_output;
	parser_out_struct fifo_input,fifo_output;
	logic full,empty,insert_flag,exit_flag;
	parser_out_struct queue[$ : DEPTH-1];
	parser_out_struct buffer_q [$];
	parser dut (.*);
	fifo top (CPU_clock, rst_n, full, empty,parser_output ,fifo_output,queue,insert_flag,exit_flag);

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
		$stop;
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
			$strobe("Simulation_time:%0t\tqueue:%p ",$time,queue);
	end
`endif

//printing statemnets for buffer queue
`ifdef queuedebug_temp
	always@(posedge CPU_clock) begin
		$strobe("_______time___________:%0t	Queue:%p",$time,buffer_q );
	end
`endif

endmodule
