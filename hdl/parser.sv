/****************************************************************
 * parser.sv - parses the input file and generates
 *
 * Author        : Viraj Khatri (vk5@pdx.edu)
 * Last Modified : 20th October, 2021
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
	output logic                           op_ready_s, // strobe signal, new op available to latch
	output parsed_op_t                     opcode,
	output logic       [ADDRESS_WIDTH-1:0] address,

	// debugging outputs
	output parser_states_t                 state
);

// open input trace file
localparam string FILE_IN = "trace_file";
int trace_file;
initial begin
	trace_file = $fopen(FILE_IN, "r");
	if (trace_file == 0) begin
		$display("%s handle was NULL", FILE_IN);
		$finish;
	end
end

// variables to store input from trace file
int clock_count = 0;
int temp_clock = 0;
parsed_op_t temp_op = NOP;
logic [ADDRESS_WIDTH-1:0] temp_address = 0;


// reading from file every clock pulse
int scan_file;
always_ff@(posedge clk) begin
	clock_count++;
	scan_file = $fscanf(trace_file, "%d %d %h\n", temp_clock, temp_op, temp_address);
	//if (!$feof(trace_file)) begin
	//end
end

// internal variables
parser_states_t curr_state, next_state;
assign state = curr_state;

// next state logic
always_comb begin
	unique case(curr_state)
		READING : begin
			// clock_count == temp_clock-1 is checked as entry to next stage as stage
			// transistion will happen on half clock cycle (negedge clk) thus
			// the state will be NEW_OP when new data is to be outputted
			if (clock_count == temp_clock-1) next_state = NEW_OP;
			else next_state = READING;
		end
		NEW_OP : begin
			if (clock_count == temp_clock) next_state = STROBE_DONE;
		end
		STROBE_DONE : begin
			// same as explained in READING state, keep state same
			if (clock_count == temp_clock-1) next_state = NEW_OP;
			else next_state = STROBE_DONE;
		end
	endcase
end

// state transistion
always_ff@(posedge clk or negedge clk or negedge rst_n) begin
	if (!rst_n) begin
		curr_state = READING;
	end else begin
		curr_state = next_state;
	end
end

// data path
always_comb begin
	unique case(curr_state)
		READING : begin
			op_ready_s = 1'b0;
			opcode = NOP;
			address = 'X;
		end
		NEW_OP : begin
			if (temp_clock == clock_count) begin // strobe only required when clock count actually matches
				op_ready_s = 1'b1;           // data on output signals is not latched without strobe
				address = temp_address;
				opcode = temp_op;
			end
		end
		STROBE_DONE : begin
			op_ready_s = 1'b0; // address on output signal does not need to be changed as strobe is set to low,
			                   // This enables the next new_op state to send a posedge on op_ready_s
		end
	endcase
end

endmodule : parser
