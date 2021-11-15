/****************************************************************
 * fifo.sv - fifo based queue
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 11th November, 2021
 *
 * Description   :
 * -----------
 * Stores outputs from parser module in a fifo queue
 * storage structure -
 * CPU_clk_count, opcode, address, op_ready_s, life
 ***************************************************************/
import global_defs::*;

module fifo
(
	//inputs
	input  logic             CPU_clock, rst_n,
	input  parser_out_struct fifo_input,             // output from parser connected to input to queue

	//outputs
	output parser_out_struct fifo_output,            // sending memory request outbound to memory
	output logic             full, empty,            // queue status registers
	output logic             insert_flag, exit_flag, // new element inserted to queue, queue element removed

	// debugging output
	output parser_out_struct queue [$: DEPTH-1]      // to view queue from the testbench
);

//debugging variables
logic [31:0] q_clock_count;
parser_out_struct buffer_q[$];

// getting the data to a temp queue
always_ff@(posedge CPU_clock) begin
	if(!rst_n) begin
		buffer_q.delete();
	end
	else if(fifo_input.op_ready_s == 1'b1  ) begin
		buffer_q.push_front(fifo_input);
	end
end

//inserting data at the right time to the intended queue
always_ff@(posedge CPU_clock) begin 
	if(!rst_n) begin
		queue.delete();
		q_clock_count <= 0;
	end

	else begin
		q_clock_count++;
		
		if ((buffer_q[$].CPU_clock_count >> 31) == 1) begin
			$display("%t :    ERROR    : -ve trace file clock count, discarding", $time);
			buffer_q.pop_back();
		end

		// preventing trace file entry errors
		if (buffer_q[0].CPU_clock_count <= buffer_q[1].CPU_clock_count) begin
			$display("%t :    ERROR    : trace file has invalid timing, discarding 2nd entry from from offending parties", $time);
			$display("%t :     kept    : element:'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}'",
					$time, buffer_q[1].CPU_clock_count, buffer_q[1].opcode, buffer_q[1].address, buffer_q[1].life);
			$display("%t :   dropped   : element:'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}'",
					$time, buffer_q[0].CPU_clock_count, buffer_q[0].opcode, buffer_q[0].address, buffer_q[0].life);

			buffer_q.pop_front();
		end
		//When queue empty
		if ( (queue.size() == 0) ) begin
			full <= 1'b0;
			empty <= 1'b1;


			if( buffer_q[$].op_ready_s === 1'b1 ) begin
				q_clock_count <= buffer_q[$].CPU_clock_count;		//advancing time
				$display("%t : QUEUE_EMPTY : May advance time since queue is empty",$time);
				queue.push_front(buffer_q[$]);

				// display pretty, code horrible
				$display("%t :   INSERT    : element:'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}'",
						$time, buffer_q[$].CPU_clock_count, buffer_q[$].opcode, buffer_q[$].address, buffer_q[$].life);
				$display("%t :             : queue elements now :   '{",$time);
				for (int j=0; j < queue.size(); j++) begin
					$display("#                                                              '{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}',",
						queue[j].CPU_clock_count, queue[j].opcode, queue[j].address, queue[j].life);
				end
				$display("#                                                             }'");
				buffer_q.pop_back();
				insert_flag <= 1;
			end
			else
				insert_flag <= 0;
		end

		//when queue is not empty
		else if( queue.size() > 0 && queue.size < DEPTH   ) begin
			full <= 1'b0;
			empty <= 1'b0;
			if(buffer_q[$].CPU_clock_count == q_clock_count ) begin
				queue.push_front(buffer_q[$]);


				// display pretty, code horrible
				$display("%t :   INSERT    : element:'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}'",
						$time, buffer_q[$].CPU_clock_count, buffer_q[$].opcode, buffer_q[$].address, buffer_q[$].life);
				$display("%t :             : queue elements now:'{",$time);
				for (int j=0; j < queue.size(); j++) begin
					$display("#                                                              '{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}',",
						queue[j].CPU_clock_count, queue[j].opcode, queue[j].address, queue[j].life);
				end
				$display("#                                                             }'");


				buffer_q.pop_back();
				insert_flag <= 1;
				end
			else
				insert_flag <= 0;
		end	
		
		// queue is full
		else if (queue.size() == DEPTH )begin
			if (buffer_q[$].CPU_clock_count == q_clock_count) begin
				$display("%t :  QUEUE_FULL : Request cannot be statisfied!!! Queue is full",$time);
				$display("#                                      dropped operation :'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}'",
					buffer_q[$].CPU_clock_count, buffer_q[$].opcode, buffer_q[$].address, buffer_q[$].life);
				buffer_q.pop_back();
			end

			full <= 1'b1;
			insert_flag <= 0;
		end
		else
			insert_flag <= 0;

		end
end

//incrementing life of each element
always_ff@(posedge CPU_clock) begin
	if(queue.size() > 0) begin
		for (int i=0; i < queue.size(); i++) begin
			queue[i].life++;
		end
	end	
end


//popping out the old elements(aged 100)
always_ff@(posedge CPU_clock) begin
	exit_flag<=0;
		for (int i=0; i < queue.size(); i++) begin
			if(queue[i].life == 100) begin

				// display pretty, code horrible
				$display("%t :   AGE_POP   : The element:'{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}' was aged 100 and popped",
						$time, queue[i].CPU_clock_count, queue[i].opcode, queue[i].address, queue[i].life);


				// determining bank group, bank, column, row
				$display("%t :             : bank group=%0d, bank=%0d, column=%0d, row=%0d"
					,$time
					,((bank_group_mask & queue[i].address) >> BG_OFFSET)
					,((bank_mask & queue[i].address) >> BANK_OFFSET)
					,((column_mask & queue[i].address) >> COLUMN_OFFSET)
					,((row_mask & queue[i].address) >> ROW_OFFSET)
					);


				fifo_output <= queue[i];
				queue.delete(i);

				// display pretty, code horrible
				$display("%t :             : queue elements remain:'{",$time);
				for (int j=0; j < queue.size(); j++) begin
					$display("#                                                              '{CPU_clk:%0t, opcode:%p, address:0x%h, life:%d}',",
						queue[j].CPU_clock_count, queue[j].opcode, queue[j].address, queue[j].life);
				end
				$display("#                                                             }'");

				exit_flag <=1;
				break;
			end
			else
			begin
				exit_flag <= 0;
				fifo_output <= '0;
			end
		end
	
	end	

endmodule
