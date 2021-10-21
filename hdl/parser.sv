/****************************************************************
 * parser.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
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
	output parsed_op_t                     opcode,     // output signal corresponding to parsed op
	output logic       [ADDRESS_WIDTH-1:0] address,    // output address corresponding to parsed address

	// debugging outputs
	output parser_states_t                 state       // debugging purposes only
);

// defining file handling veriables
localparam string FILE_IN = "trace_file";
int trace_file, scan_file;

// variables to store input from trace file
int                             parsed_clock = 0;
parsed_op_t                     parsed_op = NOP;
logic       [ADDRESS_WIDTH-1:0] parsed_address = 0;

// stores how many "absolute" clock cycles have passed
int clock_count = 0;

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
		if (trace_file == 0) begin
			$display("%s handle was NULL", FILE_IN);
			$finish;
		end
	end else begin
		clock_count++;
		curr_state <= next_state;

		// file read into parsed_* variables
		// parsed_clock -> used to compare with absolute clock to drive a strobe
		//                 on op_ready_s
		// parsed_op    -> continuous assigned to output signal opcode
		// parsed_add.  -> continuous assigned to output signal address
		if (curr_state == READING) begin
			scan_file = $fscanf(trace_file, "%d %d %h\n", parsed_clock, parsed_op, parsed_address);
		end
		if ($feof(trace_file)) begin
			//if something needs to be done at EOF
		end

	end
end

/********************
 * next state logic *
 ********************/
always_comb begin
	unique case(curr_state)
		READING : begin
			next_state = NEW_OP; // we have already read the inupts at this point,
			                     // se we don't have to stay in this state for more than 1 cycle
			                     // if we loiter here we will "scan" next line in trace file
			                     // and miss one set of instructions as it will not be strobed by
			                     // op_ready_s
		end
		NEW_OP : begin
			if (clock_count == parsed_clock) next_state = READING; // we have strobed at this point, so no
			                                                       // need to read next instruction from trace file
			else next_state = NEW_OP;  // it's not time to strobe yet,
			                           // so we don't switch states
		end
	endcase
end

/*******************
 * data path block *
 *******************/
assign address = parsed_address; // because data is only latched on op_ready_s strobe
assign opcode = parsed_op;       // we can safely assign parsed data to output
                                 // without fear of providing invalid data
always_comb begin
	unique case(curr_state)
		READING : begin
			op_ready_s = 1'b0; // (valid data + posedge op_ready_s) has been delivered
			                   // so we setup for next valid data and strobe by
			                   // setting it to 0
		end
		NEW_OP : begin
			if (parsed_clock == clock_count) op_ready_s = 1'b1; // strobe only required when clock count
			                                                    // actually matches so the timing of this
			                                                    // instruction from the trace file is met
		end
	endcase
end

endmodule : parser
