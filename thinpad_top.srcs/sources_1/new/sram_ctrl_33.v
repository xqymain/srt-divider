`timescale 1ns / 1ps

 module sram_ctrl33(clk, req, wr, address_input, data_fsm_to_sram,size,wstrb,addr_ok,data_ok ,data_sram_to_fsm,address_to_sram_output, we_to_sram_output, oe_to_sram_output, ce_to_sram_output, be_to_sram_output,data_from_to_sram_input_output, busy_signal_output);

  input  wire clk ;                                 //  Clock signal
  
  //    from / to cpu
  input  wire req;                                  //  start operation signal
  input  wire wr;                                   //  With this signal, select write(when 1) or read(when 0) data...
  input  wire [ 1:0] size;                          //  Size of the data to be written (00 - 1 byte, 01 - 2 bytes, 10 - 4 bytes)
  input  wire [ 3:0] wstrb;                         //  binary enable
  input  wire [31:0] address_input;                 //  Address bus
  input  wire [31:0] data_fsm_to_sram;              //  Data to be writteb in the SRAM
  output wire        addr_ok;
  output wire        data_ok;
  output wire [31:0] data_sram_to_fsm;              //  registered data retrieved from the SRAM       (the -s2f suffix stands for SRAM to FPGA)
  
  //to sram

  output reg  [19:0] address_to_sram_output;        //  Address bus   [
  output reg         we_to_sram_output;                     //  Write enable (active-low)
  output reg         oe_to_sram_output;                     //  Output enable (active-low)
  output reg         ce_to_sram_output;                     //  Chip enable (active-low). Disables or enables the chip.
  output reg  [3:0]  be_to_sram_output;                     //  Byte enable (active-low).  one hot
  inout  wire [31:0] data_from_to_sram_input_output;//  Data bus
  
  
  output reg busy_signal_output;                    //   Busy signal


  //uesd for temparary transfer
  wire   [31:0] temp_addr;
  wire   [31:0] temp_data;

  //FSM states declaration
  localparam [4:0]
  rd0     =   3'b000,
  rd1     =   3'b001,
  rd2     =   3'b010,
  rd3     =   3'b011,
  wr0     =   3'b100,
  wr1     =   3'b101,
  wr2     =   3'b110,
  wr3     =   3'b111,
  idle    =   4'b1000;

  //	signal declaration
  reg [3:0] state_reg;

  reg [31:0] register_for_reading_data;
  reg [31:0] register_for_writing_data;

  reg register_for_splitting;

  initial
    begin

      ce_to_sram_output<=1'b1;
      oe_to_sram_output<=1'b1;
      we_to_sram_output<=1'b1;

      state_reg <= idle;

      register_for_reading_data[31:0]<=32'b0000_0000;
      register_for_writing_data[31:0]<=32'b0000_0000;

      register_for_splitting<=1'b0;

      busy_signal_output<=1'b0;

    end

  //addr_ok
  assign addr_ok = (state_reg == rd0 | state_reg == wr0) ? 1'b1:1'b0;
  assign data_ok = (state_reg == rd3 | state_reg == wr2) ? 1'b1:1'b0;

  assign temp_addr [31:0] = address_input [31:0];
  assign temp_data [31:0] = ( wstrb [3:0] == 4'b1110 && size == 2'b00) ? { 24'b0 , data_fsm_to_sram [ 7: 0]          }:
                            ( wstrb [3:0] == 4'b1101 && size == 2'b00) ? { 16'b0 , data_fsm_to_sram [15: 8]  , 8'b0  }:
                            ( wstrb [3:0] == 4'b1011 && size == 2'b00) ? {  8'b0 , data_fsm_to_sram [23:16] , 16'b0  }:
                            ( wstrb [3:0] == 4'b0111 && size == 2'b00) ? {         data_fsm_to_sram [31:24] , 24'b0  }:
                            ( wstrb [3:0] == 4'b1100 && size == 2'b01) ? { 16'b0 , data_fsm_to_sram [15: 0]          }:
                            ( wstrb [3:0] == 4'b0011 && size == 2'b01) ? {         data_fsm_to_sram [31:24] , 16'b0  }:
                            ( wstrb [3:0] == 4'b0000 && size == 2'b10) ? {         data_fsm_to_sram [31: 0]          }:
                            ( wstrb [3:0] == 4'b1000 && size == 2'b10) ? {  8'b0 , data_fsm_to_sram [23: 0]          }:
                            ( wstrb [3:0] == 4'b0001 && size == 2'b10) ? {         data_fsm_to_sram [31:24] ,  8'b0  }:
                            32'b0;

  always@(posedge clk)
  
    begin

      case(state_reg)
        idle: 
          begin   
            if(~req)
              state_reg <= idle;
            else if (req) begin
              if(wr)
                state_reg <= wr0;
              else if(~wr) 
                state_reg <= rd0;
            end
          end
        rd0:   // Address Access Time	  min-max is 
          begin
            busy_signal_output<=1'b1;
            
            address_to_sram_output[19:0]<=temp_addr [21:2];

//            state_reg <= rd1;
//          end   

//        rd1:
//          begin
            ce_to_sram_output<=1'b0;
            oe_to_sram_output<=1'b0;
            we_to_sram_output<=1'b1;
            be_to_sram_output[3:0]<=4'b0;
            
            state_reg <= rd2;
          end

        rd2:  //finish
          begin
            
            register_for_reading_data[31:0]<=data_from_to_sram_input_output[31:0];

            state_reg <= rd3;
          end

        rd3:
          begin
            ce_to_sram_output<=1'b1;
            oe_to_sram_output<=1'b1;
            we_to_sram_output<=1'b1;

            busy_signal_output<=1'b0;

            state_reg <= idle;
          end

        wr0:
          begin
            busy_signal_output<=1'b1;

            address_to_sram_output[19:0]<=temp_addr [21:2];
            register_for_writing_data[31:0]<=temp_data [31:0];

//            state_reg <= wr1;
//          end

//        wr1:
//          begin
            ce_to_sram_output<=1'b0;
            oe_to_sram_output<=1'b1;
            we_to_sram_output<=1'b0;

            be_to_sram_output[3:0]<=wstrb[3:0];

            register_for_splitting<=1'b1;

            state_reg <= wr2;

          end

        wr2: //finish
          begin

            ce_to_sram_output<=1'b1;
            oe_to_sram_output<=1'b1;
            we_to_sram_output<=1'b1;

            state_reg <= wr3;
          end

        wr3:
          begin

            busy_signal_output<=1'b0;    
            register_for_splitting<=1'b0;
            
            state_reg <= idle;

          end

      endcase

    end

  assign data_sram_to_fsm = register_for_reading_data;
  assign data_from_to_sram_input_output = (register_for_splitting) ?
            register_for_writing_data : 32'hz;
endmodule   
