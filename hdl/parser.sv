/****************************************************************
 * parser.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 16th November, 2021
 *
 * Description   :
 * -----------
 * parses trace file and outputs the op signal and address at
 * whenever queue is empty and no pending request is left
 ****************************************************************/

import global_defs::*;

// we also need filepath with tracefile, so we extrace PWD using getenv function
// make use of the SystemVerilog C programming interface
// https://stackoverflow.com/questions/33394999/how-can-i-know-my-current-path-in-system-verilog
import "DPI-C" function string getenv(input string env_name);

module parser
(
	// inputs
	input  logic               clk, rst_n,
	input  logic               queue_full,      // flag for queue being full
	input  logic               pending_request, // flag to denote if currently read trace-line
	                                            // is not dealt with yet

	// outputs
	output parser_out_struct_t out,

	// debugging outputs
	output parser_states_t     state
);

// defining file handling veriables
int unsigned trace_file, scan_file;
string trace_filename;


// variables to store input from trace file
logic                    [31:0] parsed_clock = 'x;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address = 'x;


// internal state variables
parser_states_t curr_state = WAITE, next_state;
assign state = curr_state; // debug purposes

// CPU clock generator, toggles on every clock, thus half-frequency
logic half = 1'b0;
assign CPU_clk = half;

initial begin : tracefile_load

	if (!$value$plusargs("tracefile=%s", trace_filename)) begin
		trace_filename = {getenv("PWD"), "/../traces/normal_trace.txt"};
		$display("No trace file provided in argument. eg. +tracefile=<full_path_to_file>");
		$display("taking trace file as default (%s) provided in repository", trace_filename);
	end
	trace_file = $fopen(trace_filename, "r");
	if (trace_file == 0) begin
		$display("Could not open trace_file (%s)", trace_filename);
		$finish;
	end

end : tracefile_load

/*******************************************
 * memory elements of FSM                  *
 * manages -                               *
 * 1. next_state -> current_state          *
 * 2. opening and closing file on reset    *
 * 3. scanning a line when state = NEW_OP  *
 *******************************************/
always_ff@(posedge clk ) begin

	if (!rst_n) begin

		curr_state <= NEW_OP; // on reset, reloading the trace file by opening and closing it,
		$fclose(trace_file);  // this is done to start scanning lines from the start again
		trace_file <= $fopen(trace_filename, "r");

	end else begin

		curr_state <= next_state;

		if (next_state == NEW_OP) begin
			scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address);
			if(scan_file == 0) begin
				$display("Invalid trace_file entry\n");
				$finish;
			end
		end
	end
end

/*******************
 * data flow logic *
 *******************/
assign out.opcode = parsed_op;
assign out.address = parsed_address;
assign out.time_cpu = parsed_clock;

always_comb begin
	unique case(curr_state)
		WAITE: begin
			out.op_ready_s = 1'b0;
		end
		NEW_OP : begin
			out.op_ready_s = 1'b1;
		end
	endcase
end

/********************
 * next state logic *
 ********************/
always_comb begin
	unique case(curr_state)
		WAITE : begin
			if (!queue_full && !pending_request) next_state = NEW_OP;
			else next_state = WAITE;
		end
		NEW_OP : begin
			next_state = WAITE;
		end
	endcase
end
endmodule : parser
