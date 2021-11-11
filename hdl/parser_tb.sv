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
parameter POINTER_SIZE = $clog2(QUEUE_SIZE)+1;
parameter BITS_FOR_100 = $clog2(100);
int unsigned                        CPU_cycle_count;
logic                               clk, rst_n;
logic                               op_ready_s;
logic           [ADDRESS_WIDTH-1:0] address;
parsed_op_t                         opcode;
parser_states_t                     state;

//output from queue
parsed_op_t                         opcode_out;
logic           [ADDRESS_WIDTH-1:0] address_out;

//debugging outputs from queue
logic           [POINTER_SIZE-1:0]  read_p_out;
logic           [POINTER_SIZE-1:0]  write_p_out;
logic           [ADDRESS_WIDTH-1:0] address_queue [QUEUE_SIZE];
parsed_op_t                         opcode_queue [QUEUE_SIZE];
logic           [BITS_FOR_100-1:0]  counter_queue [QUEUE_SIZE];
logic                               CPU_clk;

parser dut (.*);

queue queue_inst(.CPU_clk(CPU_clk),
				.rst_n(rst_n),
				.op_ready_s(op_ready_s), // operation ready strobe, new operation available on input
				.opcode_in(opcode),  // opcode from operation
				.address_in(address), // address from operation
				// outputs
				.opcode_out(opcode_out),
				.address_out(address_out),
				.read_p_out(read_p_out),
				.write_p_out(write_p_out),
				.address_queue(address_queue),
				.opcode_queue(opcode_queue),
				.counter_queue(counter_queue));

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
