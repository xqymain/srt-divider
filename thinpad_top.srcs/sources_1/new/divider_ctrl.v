module divider_ctrl (
    input  wire div_clk,                    // Clock signal
    input  wire resetn,                  // Active-high reset signal

    output reg  req_base_ram,               // Request to base ram signal
    output reg  req_ext_ram,              // Request to ext ram signal
    
    (* mark_debug = "true" *)output reg  [31:0] addr_base_ram,
    (* mark_debug = "true" *)output reg         wr_base_ram,
    (* mark_debug = "true" *)input  wire        base_ram_addr_ok,       // Base RAM address OK signal  
    (* mark_debug = "true" *)input  wire        base_ram_data_ok,       // Base RAM data OK signal    
    (* mark_debug = "true" *)input  wire [31:0] rdata_base_ram,  // Read data from base RAM
    (* mark_debug = "true" *)output reg  [31:0] wdata_base_ram,   // Write data to base RAM

    (* mark_debug = "true" *)output reg  [31:0] addr_ext_ram,
    (* mark_debug = "true" *)input  wire ext_ram_addr_ok,        // Extended RAM address OK signal
    (* mark_debug = "true" *)input  wire ext_ram_data_ok,        // Extended RAM data OK signal
    (* mark_debug = "true" *)output reg  [31:0] wdata_ext_ram,   // Write data to extended RAM;
    
    (* mark_debug = "true" *)output wire        div,    // Divide begin signal
    (* mark_debug = "true" *)output wire [31:0] x,        // 32-bit dividend 
    (* mark_debug = "true" *)output wire [31:0] y,         // 32-bit y
    (* mark_debug = "true" *)output wire        div_signed,            // sign
    (* mark_debug = "true" *)input  wire [31:0] s,        // 32-bit s result
    (* mark_debug = "true" *)input  wire [31:0] r,       // 32-bit r result
    (* mark_debug = "true" *)input  wire        complete,      // Divide done signal
    (* mark_debug = "true" *)output reg  [15:0] div_cnt,
    (* mark_debug = "true" *)output reg  [19:0] clk_cnt
);
    wire reset;
    assign reset = ! resetn;

    parameter init_read_addr  = 32'h8000_0000;
    parameter init_write_addr = 32'h8040_0000;
    parameter div_total = 16'd5000;
//    reg [19:0] clk_cnt;
    reg [1:0] run_ctrl;
    localparam [3:0]
        IDLE    = 4'b0000,
        READ    = 4'b0001,
        DIVIDE  = 4'b0010,
        WRITE   = 4'b0011,
        STOP    = 4'b0100,
        W_RES   = 4'b1000;


    (* mark_debug = "true" *) reg  [ 3:0] state;
    (* mark_debug = "true" *)reg  [ 2:0] read_state , write_state;
    reg  [64:0] temp_divide;            //{sign,y,x}
    reg         read_done, write_done;
    // (* mark_debug = "true" *)reg  [20:0] div_cnt;
    reg  [31:0] s_temp,r_temp;
    initial begin
        clk_cnt <= 20'b0;
        run_ctrl <= 2'd0;
    end

    always @(posedge div_clk) begin
        if (reset) begin
            clk_cnt <= 20'b0;
        end else  if ((div_cnt !== div_total )&& run_ctrl ==2'b1) begin 
            if (clk_cnt < 20'hfffff) begin
                clk_cnt <= clk_cnt + 1 ;
                end
        end
    end

    always @(posedge div_clk) begin
        if (reset) begin
            // Reset all states and variables
            state <= IDLE;
            div_cnt<=20'b0;;
            run_ctrl<=2'd1;

            req_base_ram <= 1'b0;
            addr_base_ram <= init_read_addr;
            wr_base_ram <= 1'b0;
            wdata_base_ram <= 32'd0;
            temp_divide <= 65'd0;
            read_state <= 3'd0;
            read_done <= 1'b0;

            req_ext_ram <= 1'b0;
            addr_ext_ram <= init_write_addr;
            wdata_ext_ram <= 32'd0;
            write_state <= 3'd0;
            write_done <= 1'b0;
            s_temp<=32'b0;
            r_temp<=32'b0;

        end else if (run_ctrl == 2'd1 | run_ctrl == 2'd2) begin
            case (state)
                IDLE: begin
                    if (!reset) begin
                        if(div_cnt == div_total ) begin
                            state <= W_RES ;//WRITE TIME COST
                            run_ctrl <= 2'd2;
                        end
                        else begin
                            state <= READ;
                            read_state <= 3'd0;
                            read_done <= 1'b0;
                        end
                    end
                end

                READ: begin
                    case (read_state)
                        3'd0: begin
                            req_base_ram <= 1'b1;
                            wr_base_ram <= 1'b0;        //read cycle wr = 0
                            if (base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd1;
                            end
                        end

                        3'd1: begin
                            if (base_ram_data_ok) begin
                                temp_divide[31:0] <= rdata_base_ram[31:0];    // Get 32 x for divider [31:0]
                                addr_base_ram <= addr_base_ram + 4;
                                req_base_ram <= 1'b1;
                                read_state <= 3'd2;
                            end
                        end

                        3'd2: begin
                            if (base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd3;
                            end
                        end

                        3'd3: begin
                            if (base_ram_data_ok) begin
                                temp_divide[63:32] <= rdata_base_ram[31:0];  // Get 32 y for divider [63:32]
                                addr_base_ram <= addr_base_ram + 4;
                                req_base_ram <= 1'b1;
                                read_state <= 3'd4;
                            end
                        end

                        3'd4: begin
                            if(base_ram_addr_ok) begin
                                req_base_ram <= 1'b0;
                                read_state <= 3'd5;
                            end
                        end 

                        3'd5: begin
                            if (base_ram_data_ok) begin
                                temp_divide[64] <= rdata_base_ram[0];  // Get sign
                                addr_base_ram <= addr_base_ram + 4;
                                read_done <= 1'b1;
                                read_state <= 3'd6;     //read done
                                state <= DIVIDE;
                            end
                        end

                    endcase
                end

                DIVIDE: begin
                   if (complete) begin
                    // if (1) begin
                        s_temp<=s;
                        r_temp<=r;
                        state <= WRITE;
                        write_state <= 3'd0;
                        write_done <= 1'b0;
                    end
                end

                WRITE: begin
                    // Handle the write process to ext RAM
                    case (write_state)
                        3'd0: begin
                            req_ext_ram <= 1'b1;
                            wdata_ext_ram <= s_temp;
                            if (ext_ram_addr_ok) begin
                                req_ext_ram <= 1'b0;
                                write_state <= 3'd1;
                            end
                        end

                        3'd1: begin
                            if (ext_ram_data_ok) begin
                                addr_ext_ram <= addr_ext_ram + 4;
                                req_ext_ram <= 1'b1;
                                // wdata_ext_ram <= temp_result[63:32];
                                wdata_ext_ram <= r_temp;
                                write_state <= 3'd2;
                            end
                        end
  
                        3'd2: begin
                            if (ext_ram_addr_ok) begin
                                req_ext_ram <= 1'b0;
                                write_state <= 3'd3;
                            end
                        end

                        3'd3: begin
                            if (ext_ram_data_ok) begin
                                write_done <= 1'b1;
                                addr_ext_ram <= addr_ext_ram + 4;
                                div_cnt <=div_cnt +1;
                                state <= IDLE;
                            end
                        end
                    endcase
                end
                
                W_RES: begin     //write clk_cnt to base ram
                    req_base_ram <= 1'b1;
                    wr_base_ram <= 1'b1;
                    addr_base_ram <= init_read_addr;
                    wdata_base_ram[31:0] <= {12'b0,clk_cnt[19:0]};
                    if(base_ram_addr_ok) begin
                        req_base_ram <= 1'b0;
                    end
                    if(base_ram_data_ok) begin
                        state <= STOP;
                    end                
                end
                
                STOP:begin 
                    req_base_ram <= 1'b0;
                    req_ext_ram <= 1'b0;
                    run_ctrl <= 2'd0;
                end
            endcase
        end
    end
    
    assign div          = (state == DIVIDE) ? 1'b1 : 1'b0;
    assign x            = (div) ? temp_divide[31: 0]: 32'bz;
    assign y            = (div) ? temp_divide[63:32]: 32'bz;
    assign div_signed   = (div) ? temp_divide[64]   :  1'bz;


endmodule
