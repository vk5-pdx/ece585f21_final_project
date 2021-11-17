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
	input  clk, rst_n,

	// inputs from parser
	input  parser_out_struct_t in,                    // has op_ready_s, opcode, address and time_cpu

	// outputs to parser
	output logic               pending_request,       // flag - request is not acknowledged yet
	output logic               queue_full,            // flag - queue is full

	// outputs
	output parser_out_struct_t out,                   // output to next module (memory controller / DRAM?)
	output parser_out_struct_t queue[$:QUEUE_SIZE-1], // queue to store many memory requests
	output age_counter_t       age[$:QUEUE_SIZE-1],
	output unsigned int        queue_time,            // display what time is queue currently at
);


unsigned int curr_time;
assign queue_time = curr_time;

/***************************
 * flags to send to parser *
 ***************************/
always_comb begin : parser_flags
	if (in.op_ready_s == 1'b1) pending_request = 1'b1;
	else pending_request = 1'b0;

	if (queue.size() == QUEUE_SIZE) queue_full = 1'b1;
	else queue_full = 1'b0;
end : parser_flags

/****************************
 * taking input from parser *
 ****************************/
always_ff@(posedge clk or negedge rst) begin : parser_in
	if (!rst_n) begin
		queue.delete();
		curr_time <= 0;
	end else begin
		if (op_ready_s == 1'b1) begin
			if (queue.size() < QUEUE_SIZE) begin
				queue.push_front(in);
				age.push_front(0);
			end

			if (queue.size() == 0) begin
				curr_time <= in.time_cpu;
			end else begin
				curr_time++;
			end
		end
	end
end : parser_in

/*******************
 * aging all queue *
 *******************/
always_ff@(posedge clk) begin : queue_age
	for (int i=0; i<queue.size(); i++) begin
		age[i]++;
	end
end : queue_age

/*********************
 * output from queue *
 *********************/
always_ff@(posedge clk) begin : age_pop
	if (age[$] == 100) begin
		out <= queue[$];
		queue.pop_back();
		age.pop_back();
	end
end : age_pop


endmodule : queue
