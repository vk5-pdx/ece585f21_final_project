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
	input  logic                           clk, rst_n,

	// outputs
	output parsed_op_t                     opcode,     // output signal corresponding to parsed op
	output logic       [ADDRESS_WIDTH-1:0] address,    // output address corresponding to parsed address

	// debugging outputs
	output parser_states_t                 state,      // debugging purposes only
	output int unsigned                    clock_count
);

// defining file handling veriables
localparam string FILE_IN = "../trace_file.txt"; // trace file is the example in the description
int unsigned trace_file, scan_file;

// variables to store input from trace file
int                             parsed_clock = 0;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address = 0;



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
always_ff@(posedge clk or negedge clk or negedge rst_n) begin

	if (!rst_n) begin
		clock_count <= 0;                   // clock count to 0 under reset to restart all
		                                    // parsing on demand

		curr_state <= READING;                      // on reset, reloading the trace file by
		$fclose(trace_file);                        // opening and closing it, this is done
		trace_file <= $fopen(FILE_IN, "r");         // to start scanning lines from the start again

	end else begin
		clock_count <= clock_count + 0.5;		//clock_count increases in 0.5 because this block is operated in both clock edges
		curr_state <= next_state;


	end
end

/****************************
 *     next state logic     *
 * modeled as mealy machine *
 ****************************/
always_comb begin
	unique case(curr_state)
		READING : begin
			scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address); //first read by reset
			if (clock_count  == parsed_clock) begin
				next_state = READING;     // if condition statifies read the next line and strobe the 
				address = parsed_address; // values
				opcode = parsed_op;
			end
			else next_state = NEW_OP;

		end
		NEW_OP : begin
			if (clock_count  == parsed_clock) begin // This condition is used when the instruction is in the next clock cycle
				next_state = READING;
				address = parsed_address;
				opcode = parsed_op;
				scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address);
			end
			else next_state = NEW_OP;
		end
	endcase
end
endmodule
