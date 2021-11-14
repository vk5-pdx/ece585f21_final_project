/****************************************************************
 * fifo.sv - parses the input file and generates
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 11th November, 2021
 *
 * Description   :
 * -----------
 * parses trace file and outputs the op signal, CPU_clock_count and address at
 * specified clock cycle and removes the element when aged 100 */
import global_defs::*;
module fifo(CPU_clock, rst_n, full, empty, fifo_input,fifo_output,queue,insert_flag,exit_flag);
parameter DEPTH=16;
//inputs
input logic CPU_clock, rst_n;
input parser_out_struct fifo_input;

//outputs
output parser_out_struct fifo_output;
output logic full, empty;
output parser_out_struct queue [$: DEPTH-1];
output logic insert_flag, exit_flag;

//debugging variables
logic [31:0] q_clock_count;
integer unsigned i;
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
		
		//When queue empty
		if ( (queue.size() == 0) ) begin
			full <= 1'b0;
			empty <= 1'b1;

			if( buffer_q[$].op_ready_s === 1'b1 ) begin
				q_clock_count <= buffer_q[$].CPU_clock_count;		//advancing time
				$display("Time:%t\tMay advance time since queue is empty",$time);
				queue.push_front(buffer_q[$]);
				$display("Time:%0t\tElement_inserted:%p",$time,buffer_q[$]);
				buffer_q.pop_back();
				insert_flag <= 1;
			end
			else
				insert_flag <= 0;
		end
		//concurrent read write
		else if (buffer_q[$].CPU_clock_count == q_clock_count ) begin
			queue.push_front(buffer_q[$]);
			$display("Time:%0t\tElement_inserted:%p",$time,buffer_q[$]);
			buffer_q.pop_back();
			insert_flag <= 1;
		end
		//when queue is not empty
		else if( queue.size() > 0 && queue.size < DEPTH   ) begin
			full <= 1'b0;
			empty <= 1'b0;
			if(buffer_q[$].CPU_clock_count == q_clock_count ) begin
				queue.push_front(buffer_q[$]);
				$display("Time:%0t\tElement_inserted:%p",$time,buffer_q[$]);
				buffer_q.pop_back();
				insert_flag <= 1;
				end
			else
				insert_flag <= 0;
		end	
		
		else if (queue.size() == DEPTH )begin
			empty <= 1'b0;
			full <= 1'b1;
			$display("Time: %0t\tRequest cannot be statisfied!!! Queue is full",$time);
			insert_flag <= 0;
		
		end
		else
			insert_flag <= 0;

		end
end

//incrementing life of each element
always_ff@(posedge CPU_clock) begin
	if(queue.size() > 0) begin
		for ( i=0; i < queue.size(); i++) begin
			queue[i].life++;
		end
	end	
end


//popping out the old elements(aged 100)
always_ff@(posedge CPU_clock) begin
	exit_flag<=0;
		for ( i=0; i < queue.size(); i++) begin
			if(queue[i].life == 100) begin
				$display("Time:%t\tThe element:%p was aged 100 and popped",$time,queue[i]);
				fifo_output <= queue[i];
				queue.delete(i);
				$display("Time:%t\tThe remaining elements of queue are:%p",$time,queue);
				exit_flag <=1;
			end
			else
			begin
				exit_flag <= 0;
				fifo_output <= '0;
			end
		end
	
	end	

endmodule