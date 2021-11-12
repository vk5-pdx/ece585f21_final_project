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
logic                    [31:0] parsed_clock ;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address ;





always_ff@(posedge CPU_clock ) begin

	if (!rst_n) begin
		parser_output.CPU_clock_count <= 0; // clock count to 0 under reset to restart all
		                                    // parsing on demand
											// on reset, reloading the trace file by opening and closing it,
		$fclose(trace_file);                // this is done to start scanning lines from the start again
		parser_output.op_ready_s <= 1'b0;

		if (!$value$plusargs("tracefile=%s", trace_filename)) begin
			trace_filename = {getenv("PWD"), "/../trace_file.txt"};
			$display("No trace file provided in argument. eg. +tracefile=<full_path_to_file>");
			$display("taking trace file as default (%s) provided in repository", trace_filename);
		end
		trace_file <= $fopen(trace_filename, "r");

	end else begin

		scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address);
			parser_output.op_ready_s = 1'b1;
			parser_output.CPU_clock_count <= parsed_clock;
			parser_output.opcode <= parsed_op;
			parser_output.address <= parsed_address;
			parser_output.life <= '0;

		if(scan_file == 0)
		begin
			$display("Invalid trace_file entry\n");
			$finish;
		end

		//op_ready_s set to 1 after the end of file so that the last line is not parsed again or more times.
		if (scan_file =='1) begin
			parser_output.op_ready_s <= 1'b0;
		end

	end
end

endmodule
