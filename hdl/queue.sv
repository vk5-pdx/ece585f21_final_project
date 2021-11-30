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
	output queue_output_t      out,             // contains the command and address to which command is issued
	output int_t               queue_time       // output back to parser to solve edge-cases
);


int_t curr_time;
assign queue_time = curr_time;

wire output_allowed;
logic half_clk;
parser_out_struct_t out_buffer;
logic [$clog2(QUEUE_SIZE)-1:0] out_queue_index; // queue index of currently outgoing item

age_counter_t age[$:QUEUE_SIZE-1];
parser_out_struct_t queue[$:QUEUE_SIZE-1]; // storage

// array for tracking bank statuses
bank_status_t bank_status[16];

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
	end

	else begin

		// output from queue
		decide_output_buffer();

		// taking input from parser
		if (in.op_ready_s) begin
			if (queue.size() == 0) begin
				curr_time <= in.time_cpu; // time skip in empty queue
				if ($test$plusargs("debug")) $display("%t : QUEUE_EMPTY : queue is empty, advancting time to %0t",$time,in.time_cpu);
			end

			if ((queue.size() < QUEUE_SIZE && curr_time >= in.time_cpu) || queue.size() == 0) begin
				queue.push_front(in);
				age.push_front(0);
				pending_request <= 1'b0;


				if ($test$plusargs("debug")) begin
					$display("%t :   INSERT    : element:'{time_cpu:%0t, opcode:%p, address:0x%h}' : curr_time=%0d",
					          $time,
					          in.time_cpu,
					          in.opcode,
					          in.address,
					          curr_time);
					$display("%t :             : queue has %0d elements now :   '{",$time, queue.size());
					for (int j=0; j < queue.size(); j++) begin
						$display("#                                                              '{time_cpu:%0t, opcode:%p, address:0x%h}' '{age:%d}',",
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
				if ($test$plusargs("debug"))
					$display("%t :  REFRESHED  : outgoing DRAM commands resumed : curr_time = %0d", curr_time);
				refi_counter <= T_REFI;
				rfc_counter <= T_RFC;
				out_allowed_refresh <= 1;
			end
			else begin
				if ($test$plusargs("debug") && rfc_counter == T_RFC)
					$display("%t :   REFRESH   : outgoing DRAM commands halted : curr_time = %0d", curr_time);
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
logic output_allowed_normal;
assign (pull0, pull1) output_allowed = output_allowed_normal;

always_ff@(posedge half_clk) begin
	if (output_allowed) begin
		out <= out_buffer;
		output_allowed_normal <= 0;

		if ($test$plusargs("debug"))
			queue_output_display(out_buffer); // age popping last element, so display that

		queue.pop_back();
		age.pop_back();

		if ($test$plusargs("debug")) begin
			$display("%t :             : queue has %0d elements now :   '{", $time, queue.size());
			for (int j=0; j < queue.size(); j++) begin
				$display("#                                                              '{time_cpu:%0t, opcode:%p, address:0x%h}' '{age:%d}',",
							  queue[j].time_cpu,
							  queue[j].opcode,
							  queue[j].address,
							  age[j]);
			end
			$display("#                                                             }'");
		end
	end
end

/*****************************
 * Out Buffer decision block *
 *****************************/
function automatic decide_output_buffer();



	// forcing age pop on 100+ CPU_clock old entries
	if (age[$] >= 100) begin
		out_buffer <= queue[$]; // overwrites decision from decide_output_buffer
		output_allowed_normal <= 1;
	end

endfunction

endmodule : queue
