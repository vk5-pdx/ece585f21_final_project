/****************************************************************
 * parser_TB.sv - Testbench for parser
 *
 * Authors       : Viraj Khatri (vk5@pdx.edu)
 *               : Varden Prabahr (nagavar2@pdx.edu)
 *               : Sai Krishnan (saikris2@pdx.edu)
 *               : Chirag Chaudhari (chirpdx@pdx.edu)
 * Last Modified : 22th October, 2021
 *
 * Description   :
 * -----------
 * Testbench for parser
 ****************************************************************/
 import global_defs::*;
 module parser_tb();

    //naming variables for the design
    parameter ADDRESS_WIDTH = 32;
    logic                       clk, rst_n;
    logic                       op_ready_s; 
    logic                       [ADDRESS_WIDTH-1:0] address;
	parsed_op_t                 opcode; 
        
	parser_states_t             state;    
  
    parser dut (.*);

     initial begin          //generating clock
	clk = 0;
	forever #1 clk = ~clk;
end

    initial begin
          
        $monitor ("TIme = %t    MemCode = %d    address = %h",$time,opcode,address); //monitors output when the address or opcode changes
        rst_n = 1'b0;
        #10;
        rst_n = 1'b1;
        op_ready_s = 1'b0;
        #1000;

        $stop;
        
    end
 endmodule