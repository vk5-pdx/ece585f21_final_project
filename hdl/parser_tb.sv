/****************************************************************
 * parser_TB.sv - Testbench for parser
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 6th November, 2021
 *
 * Description   :
 * -----------
 * Testbench for parser
 ****************************************************************/
import global_defs::*;
module parser_tb();

	//naming variables for the design
parameter ADDRESS_WIDTH = 32;
int unsigned                        CPU_cycle_count;
logic                               clk, rst_n;
logic                               op_ready_s;
logic           [ADDRESS_WIDTH-1:0] address;
parsed_op_t                         opcode;
parser_states_t                     state;

parser dut (.*);

/* Clock gen */
initial begin
	clk = 0;
	forever #5 clk = ~clk;
end

initial begin
	$display("10 simulation ticks = 1 clock cycle");
	rst_n = 1'b0;
	#10;
	rst_n = 1'b1;
	#10000;
	$stop;
end

always@(opcode, address, op_ready_s) begin
	if ($test$plusargs("debug")) $strobe ("%d : CPU_cycle_count = %d\tMemCode = %d\tAddress = %h\top_ready_s = %b"
	                                      ,$time
	                                      ,CPU_cycle_count
	                                      ,opcode
	                                      ,address
	                                      ,op_ready_s); //monitors output when the address or opcode changes
end

endmodule : parser_tb
