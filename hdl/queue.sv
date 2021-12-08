/****************************************************************
 * queue.sv - queue structure for storing memory requests
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 16 November, 2021
 *
 * Description   :
 * -----------
 * takes input from parser, and stores in queue
 ****************************************************************/

import global_defs::*;

module queue
(
	// inputs
	input  logic               clk, rst_n,

	// inputs from parser
	input  parser_out_struct_t in,              // has op_ready_s, opcode, address and time_cpu

	// outputs to parser
	output logic               pending_request, // flag - request is not acknowledged yet
	output logic               queue_full,      // flag - queue is full

	// outputs
	output parser_out_struct_t out,                   // output to next module (memory controller / DRAM?)
	output parser_out_struct_t queue[$:QUEUE_SIZE-1], // queue to store many memory requests
	output age_counter_t       age[$:QUEUE_SIZE-1],
	output int_t               queue_time             // display what time is queue currently at (int)
);


int_t curr_time;
assign queue_time = curr_time;

wire output_allowed;
logic half_clk;
parser_out_struct_t out_buffer;

// validation purpose of current operation state
operations_to_do_in_order_t current_operation_state[2**BG_WIDTH][2**BANK_WIDTH];
for (genvar i=0; i<(2**BG_WIDTH); i++) begin
	for (genvar j=0; j<(2**BANK_WIDTH); j++) begin
		assign current_operation_state[i][j] = bank_status[i][j].curr_operation;
		// not using current_operation_state in following design, can be ignored
	end
end

dram_output_t out_dram;

// array for tracking bank statuses
bank_status_t bank_status[2**BG_WIDTH][2**BANK_WIDTH];

// tracking what operation in the bank_status array was last done
// to decide what t_R/C/W delay to follow
prev_operation_t previous_operation;

logic output_allowed_normal;

int unsigned dram_file;
string dram_filename = "dram";

// for access scheduling, checking if current queue entry is inserted
logic [QUEUE_SIZE-1:0] is_active;

// to check which command was just outputted to dram
logic [$clog2(QUEUE_SIZE)-1:0] is_outputted;

// need to check if access scheduling is not violating t_rrd
// Because we are checking multiple things, we can't have a downcounter
// waiting for a 0, we have to count up and then compare whenever we want to
// provide a new row address i.e. ACTIVATE command
logic [TIMER_WIDTH-1:0] activate_countup;

// similarly for activate operation countup, but for t_ccd, and t_wtr
logic [TIMER_WIDTH-1:0] column_countup;

initial begin : dram_file_open
	dram_file = $fopen(dram_filename, "w");
	if (dram_file == 0) begin
		$fatal("Could not open dram output file (%s)", dram_filename);
	end
end

/***************************
 * flags to send to parser *
 ***************************/
always_comb begin : queue_flag
	if (queue.size() == QUEUE_SIZE) queue_full = 1'b1;
	else queue_full = 1'b0;
end : queue_flag

/*************************
 * print on queue output *
 *************************/
function automatic queue_output_display(parser_out_struct_t queue_item);
	$display("%t : OUTPUT DRAM : element:'{time_cpu:%0t, opcode:%p, address:0x%h}' : curr_time=%0d",
				 $time,
				 queue_item.time_cpu,
				 queue_item.opcode,
				 queue_item.address,
				 curr_time);

	// determining bank group, bank, column, row
	$display("%t :             : bank group=%0d, bank=%0d, column=%0d, row=%0d",
	          $time,
	          ((bank_group_mask & queue_item.address) >> BG_OFFSET),
	          ((bank_mask       & queue_item.address) >> BANK_OFFSET),
	          ((column_mask     & queue_item.address) >> COLUMN_OFFSET),
	          ((row_mask        & queue_item.address) >> ROW_OFFSET));

endfunction

/******************
 * dataflow block *
 ******************/
always_ff@(posedge clk or negedge rst_n) begin : parser_in
	if ($test$plusargs("per_clock"))
		$display("%t :    START    : full,pend=%b,%b  curr_time=%0d : in=%p", $time, queue_full, pending_request, curr_time, in);

	if (!rst_n) begin
		queue.delete();
		curr_time <= 0;
		pending_request <= 1'b0;
		out_dram.address <= '0;
		out_dram.opcode <= RD; // 0 on reset
		bank_status <= '{default: '0};
		previous_operation <= '{default: '0};
		output_allowed_normal <= 0;
		activate_countup <= '1;
		column_countup <= '1;
		is_active <= '0;
		is_outputted <= '0;
	end

	else begin



		// taking input from parser
		if (in.op_ready_s) begin

			if (queue.size() == 0 && curr_time < in.time_cpu) begin
				curr_time <= in.time_cpu; // time skip in empty queue
				if ($test$plusargs("debug_queue")) $display("%t : QUEUE_EMPTY : queue is empty, advancting time to %0t",$time,in.time_cpu);
			end

			if ((queue.size() < QUEUE_SIZE && curr_time >= in.time_cpu && queue[0] != in) || queue.size() == 0) begin
				queue.push_front(in);
				age.push_front(0);
				pending_request <= 1'b0;
				if (is_active != '0) is_active = is_active * 2; // effectively a left shift
				for (int i=0; i<(2**BG_WIDTH); i++) begin
					for (int j=0; j<(2**BANK_WIDTH); j++) begin
						bank_status[i][j].queue_location = bank_status[i][j].queue_location + 1;
					end
				end


				if ($test$plusargs("debug_queue")) begin
					$display("%t :   INSERT    : element:'{time_cpu:%0t, opcode:%p, address:0x%h}' : curr_time=%0d",
					          $time,
					          in.time_cpu,
					          in.opcode,
					          in.address,
					          curr_time);
					$display("%t :             : queue has %0d elements now :   '{",$time, queue.size());
					for (int j=0; j < queue.size(); j++) begin
							$display("#                                                              '{%0d,%0d}' - %0d,%0b - '{time_cpu:%0t, opcode:%p, address:0x%h}' '{age:%0d}',",
							           (bank_group_mask & queue[j].address) >> BG_OFFSET,
							           (bank_mask & queue[j].address) >> BANK_OFFSET,
							           j,
							           is_active[j],
							           queue[j].time_cpu,
							           queue[j].opcode,
							           queue[j].address,
							           age[j]);
					end
					$display("#                                                             }'");
				end
			end else begin
				pending_request <= 1'b1;
			end
		end

		// output from queue
		//decide_output_buffer();
		//bank_status_checks();
		decide_bank_operations();
		bank_status_and_output_update();


	end
end : parser_in

/*******************
 * aging all queue *
 *******************/
always_ff@(posedge clk) begin : queue_age
	curr_time++;
	for (int i=0; i<queue.size(); i++) begin
		age[i]++;
	end
end : queue_age

/**********************************
 * Issuing refresh after T_REFI   *
 * And blocking outputs for T_RFC *
 **********************************/
parameter REFI_COUNTER_SIZE = $clog2(T_REFI);
logic [REFI_COUNTER_SIZE-1:0] refi_counter;
parameter RFC_COUNTER_SIZE = $clog2(T_RFC);
logic [RFC_COUNTER_SIZE-1:0] rfc_counter;

logic out_allowed_refresh;
// this should overwrite other signals to stop output on low only
// as if refresh command is issued, DRAM cannot be accessed
assign (strong0, weak1) output_allowed = out_allowed_refresh;

always_ff@(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		refi_counter <= T_REFI;
		rfc_counter <= T_RFC;
	end

	else begin
		if (refi_counter == '0) begin // t_refi is done, issue a refresh command now

			if (rfc_counter == '0) begin
				if ($test$plusargs("debug_dram"))
					$display("%t :  REFRESHED  : outgoing DRAM commands resumed : curr_time = %0d", $time, curr_time);
				refi_counter <= T_REFI;
				rfc_counter <= T_RFC;
				out_allowed_refresh <= 1;
			end
			else begin
				if ($test$plusargs("debug_dram") && rfc_counter == T_RFC) begin
					$display("%t :   REFRESH   : outgoing DRAM commands halted : curr_time = %0d", $time, curr_time);
					dram_file_print('0, REF);
				end
				out_allowed_refresh <= 0;
				rfc_counter <= rfc_counter-1;

			end
		end

		else begin
			out_allowed_refresh <= 1;
			refi_counter <= refi_counter-1;
		end
	end
end

/*************************************************
 * Outputting requests to DRAM on half frequency *
 *************************************************/
always_ff@(posedge clk or negedge rst_n) begin
	if (!rst_n) half_clk = 0;
	else half_clk <= ~half_clk;
end

// this should be able to change when refresh is not holding down at 0
// thus pull0, weaker than strong0, allows refresh to overwrite
// thus pull1, stronger than weak1, allows correct output to owerwrite
assign (pull0, pull1) output_allowed = output_allowed_normal;

always_ff@(posedge half_clk) begin
	
	//if ($test$plusargs("debug_dram")) $display("%0t - output_allowed(ref, norm)=%b(%b,%b)", $time, output_allowed, out_allowed_refresh, output_allowed_normal);

	if (output_allowed) begin
		out <= out_buffer;
		output_allowed_normal <= 0;


		if ($test$plusargs("debug_dram"))
			$display("%t : PUT TO FILE : out_dram = {opcode = %s, address = %0h}", $time, out_dram.opcode, out_dram.address);

		dram_file_print(out_dram.address, out_dram.opcode);

		if (out_dram.opcode == RD || out_dram.opcode == WR) begin // full command outputted, pop from queue now
			if ($test$plusargs("debug_dram"))
				$display("%t :   POPPING   : out_dram = {opcode = %s, address = %0h}, element %0d from queue", $time, out_dram.opcode, out_dram.address, is_outputted);

		//	if ($test$plusargs("debug_queue"))
		//		queue_output_display(queue[is_outputted]); // age popping last element, so display that

			if (is_outputted == 0) begin
				queue.pop_back();
				age.pop_back();
			end
			else begin

				queue.delete(is_outputted);
				age.delete(is_outputted);
			end

			is_active[is_outputted] <= 1'b0;
		end


		if ($test$plusargs("debug_queue")) begin
			$display("%t :             : queue has %0d elements now :   '{", $time, queue.size());
			for (int j=0; j < queue.size(); j++) begin
				$display("#                                                              '{%0d,%0d}' - %0d,%0b - '{time_cpu:%0t, opcode:%p, address:0x%h}' '{age:%0d}',",
						     (bank_group_mask & queue[j].address) >> BG_OFFSET,
						     (bank_mask & queue[j].address) >> BANK_OFFSET,
							  j,
							  is_active[j],
							  queue[j].time_cpu,
							  queue[j].opcode,
							  queue[j].address,
						     age[j]);
			end
			$display("#                                                             }'");
		end
	end
end

/*************************
 * printing to dram file *
 *************************/
function automatic dram_file_print(logic [ADDRESS_WIDTH-1:0] address, DRAM_commands_t opcode);

	begin
		// temporary variables, limiting scope to this function
		logic [BG_WIDTH-1:0] bank_group;
		logic [BANK_WIDTH-1:0] bank;
		logic [ROW_WIDTH-1:0] row;
		logic [COLUMN_WIDTH-1:0] column;
		bank_group = (bank_group_mask & address) >> BG_OFFSET;
		bank       = (bank_mask & address) >> BANK_OFFSET;
		row        = (row_mask & address) >> ROW_OFFSET;
		column     = (column_mask & address) >> COLUMN_OFFSET;

		$fwrite(dram_file, "%0t\t%p", curr_time, opcode);
		unique case(opcode)
			RD: begin
				$fwrite(dram_file, "\t%0d %0d %0h", bank_group, bank, column);
			end
			WR: begin
				$fwrite(dram_file, "\t%0d %0d %0h", bank_group, bank, column);
			end
			ACT: begin
				$fwrite(dram_file, "\t%0d %0d %0h", bank_group, bank, row);
			end
			PRE: begin
				$fwrite(dram_file, "\t%0d %0d", bank_group, bank);
			end
			REF: begin
			end
		endcase

		$fwrite(dram_file, "\n");
	end

endfunction

/****************************************************
 * Update the bank_status and output file if we can *
 ****************************************************/
function automatic bank_status_and_output_update();
	begin
		// to check if we have made a decision and need to break from loop
		logic to_break = 1'b0;

		logic [BG_WIDTH-1:0] bank_group;
		logic [BANK_WIDTH-1:0] bank;
		logic [ROW_WIDTH-1:0] row;
		logic [COLUMN_WIDTH-1:0] column;
		bank_group = (bank_group_mask & out_buffer.address) >> BG_OFFSET;
		bank       = (bank_mask & out_buffer.address) >> BANK_OFFSET;
		row        = (row_mask & out_buffer.address) >> ROW_OFFSET;
		column     = (column_mask & out_buffer.address) >> COLUMN_OFFSET;

		// saturation upcount for t_ccd, t_rrd, t_wtr etc
		if (activate_countup != '1) activate_countup <= activate_countup+1'b1;
		if (column_countup != '1) column_countup <= column_countup+1'b1;

		// decrement all countdown in bank_status
		for (int i=0; i<(2**BG_WIDTH); i++) begin
			for (int j=0; j<(2**BANK_WIDTH); j++) begin
				// saturation counters, can't go below 0, need to check

				if (bank_status[i][j].countdown != 0) begin
					bank_status[i][j].countdown <= bank_status[i][j].countdown - 1'b1; // count down if a valid operation has a non-zero counter
				end
				if (bank_status[i][j].ras_countdown != 0) begin // ras countdown
					bank_status[i][j].ras_countdown <= bank_status[i][j].ras_countdown - 1'b1;
				end
				if (bank_status[i][j].rc_countdown != 0) begin // rc countdown
					bank_status[i][j].rc_countdown <= bank_status[i][j].rc_countdown - 1'b1;
				end

			end
		end

		// check if we can output, and call dram_file_write if we can
		for (int i=0; i<(2**BG_WIDTH); i++) begin
			for (int j=0; j<(2**BANK_WIDTH); j++) begin
				if (bank_status[i][j].curr_operation != NO_OP
					   && bank_status[i][j].countdown == 0) begin
					// curr_operation is not NO_OP and timer is 0, so no timing can be violated, let's output now


					if($test$plusargs("per_no_op")) begin
						$display("%t :  PER NO_OP  : cpu_time:%0t, countups(activate:column):(%0d:%0d)", $time, curr_time, activate_countup, column_countup);
						$display("%t :  PER NO_OP  : bank_status[%0d][%0d] - curr_row:%0d curr_operation:%s address:0x%h countdowns:%0d,%0d,%0d",
						           $time, i, j,
						           bank_status[i][j].curr_row,
						           bank_status[i][j].curr_operation,
						           bank_status[i][j].address,
						           bank_status[i][j].countdown,
						           bank_status[i][j].ras_countdown,
						           bank_status[i][j].rc_countdown);
				  end



					unique case(bank_status[i][j].curr_operation)
						NO_OP: begin // not possible
						end
						READ: begin
							if (    ((previous_operation.write_read_n == RD) // t_ccd
							           && ((previous_operation.bank_group == bank_group && column_countup >= T_CCD_L)
							                  || (previous_operation.bank_group != bank_group && column_countup >= T_CCD_S)
							              )
							        )
							     || ((previous_operation.write_read_n == WR) // t_wtr
							           && ((previous_operation.bank_group == bank_group && column_countup >= T_WTR_L)
							                  || (previous_operation.bank_group != bank_group && column_countup >= T_WTR_S)
							              )
							        )
							) begin

								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= RD;
								bank_status[i][j].curr_operation <= NO_OP;
								bank_status[i][j].countdown <= T_CAS+T_BURST;
								column_countup <= '0;

								previous_operation.write_read_n <= RD;

								output_allowed_normal <= 1; // new output on dram

								// because we are outputting currently outgoing op is prev_op for following cycles
								previous_operation.bank_group <= i;
								previous_operation.bank <= j;

								is_outputted = bank_status[i][j].queue_location;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end
						WRITE: begin
							if ((previous_operation.bank_group == bank_group && column_countup >= T_CCD_L)
							     || (previous_operation.bank_group != bank_group && column_countup >= T_CCD_S)
							) begin
								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= WR;
								output_allowed_normal <= 1; // new output on dram

								bank_status[i][j].curr_operation <= NO_OP;
								bank_status[i][j].countdown <= T_CWD+T_BURST;
								column_countup <= '0;
								previous_operation.write_read_n <= WR;


								// because we are outputting currently outgoing op is prev_op for following cycles
								previous_operation.bank_group <= i;
								previous_operation.bank <= j;

								is_outputted = bank_status[i][j].queue_location;

								to_break = 1'b1;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end
						ACT_READ: begin
							if (bank_status[i][j].rc_countdown == '0 // t_rc for this bank not satisfied, can't do another activate
									&& (    (previous_operation.bank_group == bank_group && activate_countup >= T_RRD_L) // checking rrds dependant
										  || (previous_operation.bank_group != bank_group && activate_countup >= T_RRD_S) // on previous command
										)
							) begin
								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= ACT;
								output_allowed_normal <= 1; // new output on dram

								bank_status[i][j].curr_operation <= operations_to_do_in_order_t'(1); // gotta typecast for READ command
								bank_status[i][j].curr_row <= row; // gotta typecast for READ command
								bank_status[i][j].countdown <= T_RCD;
								bank_status[i][j].ras_countdown <= T_RAS; // t_ras is from current act to next precharge
								bank_status[i][j].rc_countdown <= T_RC;   // t_rc, limiting access rate of 1 bank
								activate_countup <= 0;                   // t_rrd counter started here

								// because we are outputting currently outgoing op is prev_op for following cycles
								previous_operation.bank_group <= i;
								previous_operation.bank <= j;

								// precharge is used to activate, not precharged now
								bank_status[i][j].precharge_status_n <= 1'b1;
								bank_status[i][j].activation_status_n <= 1'b1;

								to_break = 1'b1;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end
						ACT_WRITE: begin
							if (bank_status[i][j].rc_countdown == '0 // t_rc for this bank not satisfied, can't do another activate
									&& (    (previous_operation.bank_group == bank_group && activate_countup >= T_RRD_L) // checking rrds dependant
										  || (previous_operation.bank_group != bank_group && activate_countup >= T_RRD_S) // on previous command
										)
							) begin
								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= ACT;
								output_allowed_normal <= 1; // new output on dram

								bank_status[i][j].curr_operation <= WRITE;
								bank_status[i][j].countdown <= T_RCD;
								bank_status[i][j].ras_countdown <= T_RAS; // t_ras is from current act to next precharge
								bank_status[i][j].rc_countdown <= T_RC;   // t_rc, limiting access rate of 1 bank
								activate_countup <= 0;                   // t_rrd counter started here

								// because we are outputting currently outgoing op is prev_op for following cycles
								previous_operation.bank_group <= i;
								previous_operation.bank <= j;

								// precharge is used to activate, not precharged now
								bank_status[i][j].precharge_status_n <= 1'b1;
								bank_status[i][j].activation_status_n <= 1'b1;

								to_break = 1'b1;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end
						PRE_ACT_READ: begin
							if (bank_status[i][j].ras_countdown == '0) begin // can't precharge until t_ras is satisfied
								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= PRE;
								output_allowed_normal <= 1; // new output on dram

								bank_status[i][j].curr_operation <= ACT_READ;
								bank_status[i][j].countdown <= T_RP;

								to_break = 1'b1;
								bank_status[i][j].activation_status_n <= 1'b0;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end
						PRE_ACT_WRITE: begin
							if (bank_status[i][j].ras_countdown == '0) begin // can't precharge until t_ras is satisfied
								out_dram.address <= bank_status[i][j].address;
								out_dram.opcode <= PRE;
								output_allowed_normal <= 1; // new output on dram

								bank_status[i][j].curr_operation <= ACT_WRITE;
								bank_status[i][j].countdown <= T_RP;

								to_break = 1'b1;
								bank_status[i][j].activation_status_n <= 1'b0;

								i = 2**BG_WIDTH;
								j = 2**BANK_WIDTH;
							end
						end


						// all states below this may be useless
						TR_L_PRE_ACT_READ: begin
							// nothing to output
							bank_status[i][j].curr_operation <= PRE_ACT_READ;
							bank_status[i][j].countdown <= T_RRD_L;
						end
						TR_S_PRE_ACT_READ: begin
							// nothing to output
							bank_status[i][j].curr_operation <= PRE_ACT_READ;
							bank_status[i][j].countdown <= T_RRD_S;
						end
						TC_L_READ: begin
							// nothing to output
							bank_status[i][j].curr_operation <= operations_to_do_in_order_t'(1); // gotta typecast for READ command
							bank_status[i][j].countdown <= T_CCD_L;
						end
						TC_S_READ: begin
							// nothing to output
							bank_status[i][j].curr_operation <= operations_to_do_in_order_t'(1); // gotta typecast for READ command
							bank_status[i][j].countdown <= T_CCD_S;
						end
					endcase

					if (to_break == 1'b1) break;
				end
				if (to_break == 1'b1) begin
					to_break = 1'b0;
					break;
				end
			end
		end

		//if($test$plusargs("debug_dram")) $display("%t : %p", $time, bank_status);
	end

endfunction

/********************************************************
 * Check if out_buffer can be inserted into bank_status *
 *   -- All commands in bank_status.curr_operations are *
 *      commands that are currently being executed for  *
 *      that bank                                       *
 ********************************************************/
function automatic bank_status_checks();
	begin


		logic [BG_WIDTH-1:0] bank_group;
		logic [BANK_WIDTH-1:0] bank;
		logic [ROW_WIDTH-1:0] row;
		logic [COLUMN_WIDTH-1:0] column;
		bank_group = (bank_group_mask & out_buffer.address) >> BG_OFFSET;
		bank       = (bank_mask & out_buffer.address) >> BANK_OFFSET;
		row        = (row_mask & out_buffer.address) >> ROW_OFFSET;
		column     = (column_mask & out_buffer.address) >> COLUMN_OFFSET;

		// for now having non-scheduled memory access, no need to check
		// curr_operation, just insert

		if ($test$plusargs("per_clk") && bank_status[bank_group][bank].countdown != '0)
			$display("%t :  PER CLOCK  : bank_status[%0d][%0d]:{curr_row:%0d curr_operation:%s address:0x%h countdown:%0d q:%0d}, is_active:0x%h, is_outputted:%d",
			            $time,
			            bank_group,
			            bank,
			            bank_status[bank_group][bank].curr_row,
			            bank_status[bank_group][bank].curr_operation,
			            bank_status[bank_group][bank].address,
			            bank_status[bank_group][bank].countdown,
			            bank_status[bank_group][bank].queue_location,
			            is_active,
			            is_outputted);


		if (bank_status[bank_group][bank].curr_operation == NO_OP && bank_status[bank_group][bank].countdown == '0) begin // can insert as prev command is done

			bank_status[bank_group][bank].address = out_buffer.address;

			for (int i=queue.size()-1; i>= 0; i--) begin
				if (is_active[i] == 1'b0) begin
					is_active[i] = 1'b1;
					bank_status[bank_group][bank].queue_location = i;
				end
			end

			if ($test$plusargs("debug_dram")) $display("%t : BANK AVLBL. : NO_OP found in bank_status[%0d][%0d] = {curr_row:%0d curr_operation:%s address:0x%h countdown:%0d}",
			                                            $time,
			                                            bank_group,
			                                            bank,
			                                            bank_status[bank_group][bank].curr_row,
			                                            bank_status[bank_group][bank].curr_operation,
			                                            bank_status[bank_group][bank].address,
			                                            bank_status[bank_group][bank].countdown);

			if ($test$plusargs("debug_dram")) $display("%t : OPER INSRT. : inserting:{opcode:%p address:0x%h time_cpu:%0d}",
			                                            $time,
			                                            out_buffer.opcode,
			                                            out_buffer.address,
			                                            out_buffer.time_cpu);


			if ($test$plusargs("debug_dram")) $display("%t :   STATUS    : (open_row,addressed_row):(%0d,%0d) (addressed_bg,prev_bg):(%0d,%0d) prev_op(w/r#):%b",
			                                       $time,
			                                       bank_status[bank_group][bank].curr_row,
			                                       row,
			                                       bank_group,
			                                       previous_operation.bank_group,
			                                       previous_operation.write_read_n);

			if (row == bank_status[bank_group][bank].curr_row && bank_status[bank_group][bank].activation_status_n != 0) begin // only read / write required
				if (out_buffer.opcode == DATA_READ || out_buffer.opcode == OPCODE_FETCH) begin
					bank_status[bank_group][bank].curr_operation = READ;
				end
				if (out_buffer.opcode == DATA_WRITE) begin
					bank_status[bank_group][bank].curr_operation = WRITE;
				end
			end

			else begin // pre+act+read/write required
				if (out_buffer.opcode == DATA_READ || out_buffer.opcode == OPCODE_FETCH) begin
					if (bank_status[bank_group][bank].precharge_status_n == 1'b0) bank_status[bank_group][bank].curr_operation = ACT_READ;
					else bank_status[bank_group][bank].curr_operation = PRE_ACT_READ;
				end
				if (out_buffer.opcode == DATA_WRITE) begin
					if (bank_status[bank_group][bank].precharge_status_n == 1'b0) bank_status[bank_group][bank].curr_operation <= ACT_WRITE;
					else bank_status[bank_group][bank].curr_operation = PRE_ACT_WRITE;
				end
			end


		end
	end

endfunction

/*************************************************
 * Decision block on what to do with queue items *
 *************************************************/
function automatic decide_bank_operations();
	begin

		logic [BG_WIDTH-1:0] bank_group;
		logic [BANK_WIDTH-1:0] bank;
		logic [ROW_WIDTH-1:0] row;
		logic [COLUMN_WIDTH-1:0] column;

		for (int i=queue.size()-1; i>=0; i--) begin    // check if queue command is already active i.e. tracked inside bank status
			// otherwise just mark it for being inserted

			if ($test$plusargs("per_clk") && bank_status[bank_group][bank].countdown != '0)
				$display("%t :  PER CLOCK  : bank_status[%0d][%0d]:{row:%0d operation:%s add:0x%h cd:%0d q:%0d}, act:0x%h, out:%d, queue:%0d",
				                 $time,
				                 bank_group,
				                 bank,
				                 bank_status[bank_group][bank].curr_row,
				                 bank_status[bank_group][bank].curr_operation,
				                 bank_status[bank_group][bank].address,
				                 bank_status[bank_group][bank].countdown,
				                 bank_status[bank_group][bank].queue_location,
				                 is_active,
				                 is_outputted,
				                 i);

			if ($test$plusargs("per_clk") && bank_status[bank_group][bank].countdown != '0)
						$displayh("%t :             : out_buffer=%p", $time, out_buffer);

			if (is_active[i] == 1'b0) begin
				bank_group = (bank_group_mask & queue[i].address) >> BG_OFFSET;
				bank       = (bank_mask & queue[i].address) >> BANK_OFFSET;
				row        = (row_mask & queue[i].address) >> ROW_OFFSET;
				column     = (column_mask & queue[i].address) >> COLUMN_OFFSET;

				// bank_status already holds some other command, can't insert new command as active
				//if (bank_status[(bank_group_mask & queue[i].address) >> BG_OFFSET][(bank_mask & queue[i].address) >> BANK_OFFSET].curr_operation != NO_OP
					//        || bank_status[(bank_group_mask & queue[i].address) >> BG_OFFSET][(bank_mask & queue[i].address) >> BANK_OFFSET].countdown != '0 ) continue;
					if (bank_status[bank_group][bank].curr_operation != NO_OP
						|| bank_status[bank_group][bank].countdown != '0 ) continue;
					else out_buffer = queue[i];


					// checking if new queue item can be inserted in bank_status
						if (bank_status[bank_group][bank].curr_operation == NO_OP && bank_status[bank_group][bank].countdown == '0) begin // can insert as prev command is done

							bank_status[bank_group][bank].address = queue[i].address;

							is_active[i] = 1'b1;
							bank_status[bank_group][bank].queue_location = i;

							if ($test$plusargs("debug_dram"))
								$display("%t : BANK AVLBL. : NO_OP found in bank_status[%0d][%0d] = {curr_row:%0d curr_operation:%s address:0x%h countdown:%0d}",
								             $time,
								             bank_group,
								             bank,
								             bank_status[bank_group][bank].curr_row,
								             bank_status[bank_group][bank].curr_operation,
								             bank_status[bank_group][bank].address,
								             bank_status[bank_group][bank].countdown);

							if ($test$plusargs("debug_dram"))
								$display("%t : OPER INSRT. : inserting:{opcode:%p address:0x%h time_cpu:%0d}",
								             $time,
								             queue[i].opcode,
								             queue[i].address,
								             queue[i].time_cpu);


							if ($test$plusargs("debug_dram"))
								$display("%t :   STATUS    : (open_row,addressed_row):(%0d,%0d) (addressed_bg,prev_bg):(%0d,%0d) prev_op(w/r#):%b",
								             $time,
								             bank_status[bank_group][bank].curr_row,
								             row,
								             bank_group,
								             previous_operation.bank_group,
								             previous_operation.write_read_n);

							if (row == bank_status[bank_group][bank].curr_row && bank_status[bank_group][bank].activation_status_n == 1'b1) begin // only read / write required
								if (queue[i].opcode == DATA_READ || queue[i].opcode == OPCODE_FETCH) begin
									bank_status[bank_group][bank].curr_operation = READ;
								end
								if (queue[i].opcode == DATA_WRITE) begin
									bank_status[bank_group][bank].curr_operation = WRITE;
								end
							end

							else begin // pre+act+read/write required
								if (queue[i].opcode == DATA_READ || queue[i].opcode == OPCODE_FETCH) begin
									if (bank_status[bank_group][bank].precharge_status_n == 1'b0) bank_status[bank_group][bank].curr_operation = ACT_READ;
									else bank_status[bank_group][bank].curr_operation = PRE_ACT_READ;
								end
							if (queue[i].opcode == DATA_WRITE) begin
								if (bank_status[bank_group][bank].precharge_status_n == 1'b0) bank_status[bank_group][bank].curr_operation <= ACT_WRITE;
								else bank_status[bank_group][bank].curr_operation = PRE_ACT_WRITE;
							end
					end





				end
			end

			//	// forcing age pop on 1000+ CPU_clock old entries
			//	if (age[$] >= 1000) begin
				//		out_buffer = queue[$]; // overwrites decisions to provide minimum QOS of 100 cycles
				//	end

			end
		end

endfunction


endmodule : queue
