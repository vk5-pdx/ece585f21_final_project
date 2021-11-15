/****************************************************************
 * parser.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 11th November, 2021
 *
 * Description   :
 * -----------
 * parses trace file and outputs the op signal and address at
 * specified clock cycle
 ****************************************************************/
// we also need filepath with tracefile, so we extrace PWD using getenv function
// make use of the SystemVerilog C programming interface
// https://stackoverflow.com/questions/33394999/how-can-i-know-my-current-path-in-system-verilog

import global_defs::*;
import "DPI-C" function string getenv(input string env_name);



module parser
(

	input  logic    CPU_clock, rst_n,
	output parser_out_struct  parser_output
);

// defining file handling veriables
int unsigned trace_file, scan_file;
string trace_filename;

// variables to store input from trace file
longint unsigned                parsed_clock ;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address ;

parser_out_struct buffer_q_parse[$];



initial begin
	int unsigned counter = 0;
	int j;
	int flag_rep;
	$fclose(trace_file);                // this is done to start scanning lines from the start again

		if (!$value$plusargs("tracefile=%s", trace_filename)) begin
			trace_filename = {getenv("PWD"), "/../trace_file.txt"};
			$display("No trace file provided in argument. eg. +tracefile=<full_path_to_file>");
			$display("taking trace file as default (%s) provided in repository", trace_filename);
		end
		trace_file = $fopen(trace_filename, "r");
	while($fscanf(trace_file, "%d %d 0x%h\n", parsed_clock, parsed_op, parsed_address) != -1) begin
			flag_rep = 0;
			for( j = 0; j < buffer_q_parse.size(); j++)
			begin
				if(buffer_q_parse[j].CPU_clock_count == parsed_clock) begin
					flag_rep = 1;
					break;
				end
				else
					flag_rep = 0;
			end
			if(flag_rep == 0) begin
				buffer_q_parse[counter].CPU_clock_count = parsed_clock;
				buffer_q_parse[counter].opcode = parsed_op;
				buffer_q_parse[counter].address = parsed_address;
				buffer_q_parse[counter].op_ready_s = 1'b1;
				buffer_q_parse[counter].life = '0;
				if ($test$plusargs("debug")) $display("Unique entry %d %d %d 0x%h\n",counter,parsed_clock, parsed_op, parsed_address);
				counter++;
			end
			else
				counter = counter;
		end
end
always_ff@(posedge CPU_clock ) begin

	if (!rst_n) begin
		parser_output.CPU_clock_count <= 0; // clock count to 0 under reset to restart all
		                                    // parsing on demand
		parser_output.op_ready_s <= 1'b0;
	end else begin
		parser_output <= buffer_q_parse.pop_front();
	end
end

endmodule
