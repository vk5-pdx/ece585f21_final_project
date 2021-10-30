/****************************************************************
 * parser.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 29th October, 2021
 *
 * Description   :
 * -----------
 * parses trace file and outputs the op signal and address at
 * specified clock cycle
 ****************************************************************/

import global_defs::*;

module parser
(
	// inputs
	input logic                           clk, rst_n,

	// outputs
	output logic                           op_ready_s,
	output parsed_op_t                     opcode,     // output signal corresponding to parsed op
	output logic       [ADDRESS_WIDTH-1:0] address,    // output address corresponding to parsed address

	// debugging outputs
	output parser_states_t                 state,      // debugging purposes only
	output int unsigned                    clock_count
);

// defining file handling veriables
int unsigned trace_file, scan_file;

// we also need filepath with tracefile, so we extrace PWD using getenv function
// make use of the SystemVerilog C programming interface
// https://stackoverflow.com/questions/33394999/how-can-i-know-my-current-path-in-system-verilog
import "DPI-C" function string getenv(input string env_name);


// variables to store input from trace file
logic                    [31:0] parsed_clock = 'x;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address = 'x;



// internal state variables
parser_states_t curr_state = READING, next_state;
assign state = curr_state; // debug purposes

/*******************************************
 * memory elements of FSM                  *
 * manages -                               *
 * 1. next_state -> current_state          *
 * 2. opening and closing file on reset    *
 * 3. scanning 1 line when state = READING *
 ******************************************/
logic half = 1'b0;
always_ff@(posedge clk ) begin

	if (!rst_n) begin
		clock_count <= 0;                   // clock count to 0 under reset to restart all
		                                    // parsing on demand
		half <= 1'b0;
		curr_state <= RESET;              // on reset, reloading the trace file by opening and closing it,
		$fclose(trace_file);                // this is done to start scanning lines from the start again
		trace_file <= $fopen({getenv("PWD"), "/../trace_file.txt"}, "r");

	end else begin
		curr_state <= next_state;
		if(half)
		clock_count++;
		half <= ~half;
		if(next_state == READING)
		scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address);
		if(scan_file == 0)
		begin
			$display("Invalid trace_file entry\n");
			$finish;
		end
	end
end

/****************************
 *     next state logic     *
 * modeled as mealy machine *
 ****************************/
//Combinational Logic
always_comb begin
	unique case(curr_state)
		RESET : begin
			op_ready_s = 1'b0;
			address = 'x;
			opcode = NOP;
		end
		READING : begin
			op_ready_s = 1'b0;
			address = 'x;
			opcode = NOP;
		end
		NEW_OP : begin
			if (clock_count == parsed_clock) begin

				address = parsed_address;
				opcode = parsed_op;
				op_ready_s = 1'b1;

			end
			else begin
				op_ready_s = 1'b0;
				address = parsed_address;
				opcode = parsed_op;
			end
		end
	endcase
end

//next state logic
always_comb begin
	unique case(curr_state)
		RESET : next_state = READING;
		READING :next_state = NEW_OP;
		NEW_OP : begin
			if (clock_count  == parsed_clock) begin
				next_state = READING;
			end
			else next_state = NEW_OP;
		end
	endcase
end
endmodule
