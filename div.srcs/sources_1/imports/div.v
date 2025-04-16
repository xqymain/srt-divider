module div #(
	// Only support WIDTH = 64/32/16
	parameter WIDTH = 32
)(
	input  div,
	input  div_signed,
	input  [WIDTH-1:0] x,
	input  [WIDTH-1:0] y,

	output complete,
	output [WIDTH-1:0] s,
	output [WIDTH-1:0] r,

	input  div_clk,
	input  resetn
);

reg div_reg;
reg div_signed_reg;
reg [WIDTH-1:0] x_reg;
reg [WIDTH-1:0] y_reg;
always @(posedge div_clk) begin
    if (~resetn) begin
		div_reg <= 1'b0;
		div_signed_reg <= 1'b0;
		x_reg <= (WIDTH-1)'b0;
		y_reg <= 32'b0;
	end
    else begin
		div_reg <= div;
		div_signed_reg <= div_signed;
		x_reg <= x;
		y_reg <= y;
	end
end

// localparams
localparam FSM_WIDTH 			= 6;
localparam FSM_IDLE_ABS_BIT	 	= 0;
localparam FSM_PRE_0_BIT	 	= 1;
localparam FSM_PRE_1_BIT	 	= 2;
localparam FSM_ITER_BIT		 	= 3;
localparam FSM_POST_0_BIT	    = 4;
localparam FSM_POST_1_BIT	 	= 5;
localparam FSM_IDLE_ABS			= 6'b00_0001;
localparam FSM_PRE_PROCESS_0 	= 6'b00_0010;
localparam FSM_PRE_PROCESS_1 	= 6'b00_0100;
localparam FSM_SRT_ITERATION 	= 6'b00_1000;
localparam FSM_POST_PROCESS_0 	= 6'b01_0000;
localparam FSM_POST_PROCESS_1 	= 6'b10_0000;

// need bits to express the Leading Zero Count of the data
localparam LZC_WIDTH = $clog2(WIDTH);

// ITN = InTerNal
// 1-bit in front of the MSB of rem -> Sign.
// 2-bit after the LSB of rem -> Used in Retiming Design.
// 3-bit after the LSB of rem -> Used for Align operation.
localparam ITN_W = 1 + WIDTH + 2 + 3;

localparam QUO_ONEHOT_WIDTH = 5;
localparam QUO_NEG_2 = 0;
localparam QUO_NEG_1 = 1;
localparam QUO_ZERO  = 2;
localparam QUO_POS_1 = 3;
localparam QUO_POS_2 = 4;
localparam QUO_ONEHOT_NEG_2 = 5'b0_0001;
localparam QUO_ONEHOT_NEG_1 = 5'b0_0010;
localparam QUO_ONEHOT_ZERO  = 5'b0_0100;
localparam QUO_ONEHOT_POS_1 = 5'b0_1000;
localparam QUO_ONEHOT_POS_2 = 5'b1_0000;

// signals
genvar i;

wire div_start_handshaked;
reg [FSM_WIDTH-1:0] fsm_d;
reg [FSM_WIDTH-1:0] fsm_q;

// 1-extra bit for LZC
wire [(LZC_WIDTH + 1)-1:0] dividend_lzc, divisor_lzc;
wire dividend_lzc_en, divisor_lzc_en;
wire [(LZC_WIDTH + 1)-1:0] dividend_lzc_d, divisor_lzc_d;
reg [(LZC_WIDTH + 1)-1:0] dividend_lzc_q, divisor_lzc_q;
// The delay of this signal is "delay(u_lzc) + delay(LZC_WIDTH-bit full adder)" -> slow
wire [(LZC_WIDTH + 1)-1:0] lzc_diff_slow;
// The delay of this signal is "delay(LZC_WIDTH-bit full adder)" -> fast
wire [(LZC_WIDTH + 1)-1:0] lzc_diff_fast;
wire [2-1:0] r_shift_num;
wire iter_num_en;
wire [(LZC_WIDTH - 2)-1:0] iter_num_d;
reg [(LZC_WIDTH - 2)-1:0] iter_num_q;
wire final_iter;

wire dividend_sign;
wire divisor_sign;
wire [WIDTH-1:0] dividend_abs;
wire [WIDTH-1:0] divisor_abs;
wire dividend_abs_en;
wire [(WIDTH+1)-1:0] dividend_abs_d;
reg [(WIDTH+1)-1:0] dividend_abs_q;
wire [WIDTH-1:0] normalized_dividend;
wire divisor_abs_en;
wire [(WIDTH+1)-1:0] divisor_abs_d;
reg [(WIDTH+1)-1:0] divisor_abs_q;
wire [WIDTH-1:0] normalized_divisor;
wire [(ITN_W + 2)-1:0] divisor_ext;
wire [WIDTH-1:0] inverter_in [1:0];
wire [WIDTH-1:0] inverter_res [1:0];

wire no_iter_needed_en;
wire no_iter_needed_d;
reg no_iter_needed_q;
wire dividend_too_small_en;
wire dividend_too_small_d;
reg dividend_too_small_q;
wire divisor_eq_zero;
wire divisor_eq_one;

wire quo_sign_en;
wire quo_sign_d;
reg quo_sign_q;
wire rem_sign_en;
wire rem_sign_d;
reg rem_sign_q;

// nr = non_redundant
wire [ITN_W-1:0] nr_rem_nxt;
wire [ITN_W-1:0] nr_rem_plus_d_nxt;
wire [(WIDTH+1)-1:0] nr_rem;
wire [(WIDTH+1)-1:0] nr_rem_plus_d;
wire nr_rem_is_zero;
wire need_corr;

wire [(WIDTH + 1)-1:0] pre_shifted_rem;
wire [WIDTH-1:0] post_r_shift_data_in;
wire [(LZC_WIDTH)-1:0] post_r_shift_num;
wire post_r_shift_extend_msb;
// S0 ~ S5 is enough for "WIDTH <= 64".
wire [WIDTH-1:0] post_r_shift_res_s0;
wire [WIDTH-1:0] post_r_shift_res_s1;
wire [WIDTH-1:0] post_r_shift_res_s2;
wire [WIDTH-1:0] post_r_shift_res_s3;
wire [WIDTH-1:0] post_r_shift_res_s4;
wire [WIDTH-1:0] post_r_shift_res_s5;
// wire [WIDTH-1:0] post_r_shift_res_s6;

wire [5-1:0] pre_m_pos_1;
wire [5-1:0] pre_m_pos_2;
wire [2-1:0] pre_cmp_res;
wire [5-1:0] pre_rem_trunc_1_4;
wire qds_para_neg_1_en;
wire [5-1:0] qds_para_neg_1_d;
reg [5-1:0] qds_para_neg_1_q;
wire qds_para_neg_0_en;
wire [3-1:0] qds_para_neg_0_d;
reg [3-1:0] qds_para_neg_0_q;
wire qds_para_pos_1_en;
wire [2-1:0] qds_para_pos_1_d;
reg [2-1:0] qds_para_pos_1_q;
wire qds_para_pos_2_en;
wire [5-1:0] qds_para_pos_2_d;
reg [5-1:0] qds_para_pos_2_q;
wire special_divisor_en;
wire special_divisor_d;
reg special_divisor_q;

wire [ITN_W-1:0] rem_sum_normal_init_value;
wire [ITN_W-1:0] rem_sum_init_value;
wire [ITN_W-1:0] rem_carry_init_value;
wire rem_sum_en;
wire [ITN_W-1:0] rem_sum_d;
reg [ITN_W-1:0] rem_sum_q;
wire rem_carry_en;
wire [ITN_W-1:0] rem_carry_d;
reg [ITN_W-1:0] rem_carry_q;
wire [ITN_W-1:0] rem_sum_nxt;
wire [ITN_W-1:0] rem_carry_nxt;

wire prev_quo_digit_en;
wire [QUO_ONEHOT_WIDTH-1:0] prev_quo_digit_d;
reg [QUO_ONEHOT_WIDTH-1:0] prev_quo_digit_q;
wire [QUO_ONEHOT_WIDTH-1:0] prev_quo_digit_init_value;
wire [QUO_ONEHOT_WIDTH-1:0] quo_digit_nxt;
wire quo_iter_en;
wire [WIDTH-1:0] quo_iter_d;
reg [WIDTH-1:0] quo_iter_q;
wire [WIDTH-1:0] quo_iter_nxt;
// m1 = minus_1
wire quo_m1_iter_en;
wire [WIDTH-1:0] quo_m1_iter_d;
reg [WIDTH-1:0] quo_m1_iter_q;
wire [WIDTH-1:0] quo_m1_iter_nxt;

wire [WIDTH-1:0] final_rem;
wire [WIDTH-1:0] final_quo;


assign div_start_handshaked = div_reg & fsm_q[FSM_IDLE_ABS_BIT];

// FSM Ctrl wire
always @(*) begin
	case(fsm_q)
		FSM_IDLE_ABS:
			fsm_d = div_reg ? FSM_PRE_PROCESS_0 : FSM_IDLE_ABS;
		FSM_PRE_PROCESS_0:
			fsm_d = FSM_PRE_PROCESS_1;
		FSM_PRE_PROCESS_1:
			fsm_d = (dividend_too_small_q | divisor_eq_zero | no_iter_needed_q) ? FSM_POST_PROCESS_0 : FSM_SRT_ITERATION;
		FSM_SRT_ITERATION:
			fsm_d = final_iter ? FSM_POST_PROCESS_0 : FSM_SRT_ITERATION;
		FSM_POST_PROCESS_0:
			fsm_d = FSM_POST_PROCESS_1;
		FSM_POST_PROCESS_1:
			fsm_d = FSM_IDLE_ABS;
		default:
			fsm_d = FSM_IDLE_ABS;
	endcase

end

always @(posedge div_clk or negedge resetn) begin
	if(~resetn)
		fsm_q <= FSM_IDLE_ABS;
	else
		fsm_q <= fsm_d;
end
// R_SHIFT
// PRE_PROCESS_1: r_shift the dividend for "dividend_too_small/divisor_eq_zero".
// POST_PROCESS_1: If "dividend_too_small/divisor_eq_zero", we should not do any r_shift. Because we have already put dividend into the correct position
// in PRE_PROCESS_1.
assign post_r_shift_num = fsm_q[FSM_PRE_1_BIT] ? dividend_lzc_q : ((dividend_too_small_q | divisor_eq_zero) ? {(LZC_WIDTH){1'b0}} : divisor_lzc_q);
assign post_r_shift_data_in = fsm_q[FSM_PRE_1_BIT] ? dividend_abs_q[WIDTH-1:0] : pre_shifted_rem[WIDTH-1:0];
assign post_r_shift_extend_msb = fsm_q[FSM_POST_1_BIT] & rem_sign_q & pre_shifted_rem[WIDTH];

assign post_r_shift_res_s0 = post_r_shift_num[0] ? {{(1){post_r_shift_extend_msb}}, post_r_shift_data_in[WIDTH-1:1]} : post_r_shift_data_in;
assign post_r_shift_res_s1 = post_r_shift_num[1] ? {{(2){post_r_shift_extend_msb}}, post_r_shift_res_s0	[WIDTH-1:2]} : post_r_shift_res_s0;
assign post_r_shift_res_s2 = post_r_shift_num[2] ? {{(4){post_r_shift_extend_msb}}, post_r_shift_res_s1 [WIDTH-1:4]} : post_r_shift_res_s1;
assign post_r_shift_res_s3 = post_r_shift_num[3] ? {{(8){post_r_shift_extend_msb}}, post_r_shift_res_s2 [WIDTH-1:8]} : post_r_shift_res_s2;

generate
if(WIDTH == 32) begin
	assign post_r_shift_res_s4 = post_r_shift_num[4] ? {{(16){post_r_shift_extend_msb}}, post_r_shift_res_s3[WIDTH-1:16]} : post_r_shift_res_s3;
	assign post_r_shift_res_s5 = post_r_shift_res_s4;
end
else if(WIDTH == 64) begin
	assign post_r_shift_res_s4 = post_r_shift_num[4] ? {{(16){post_r_shift_extend_msb}}, post_r_shift_res_s3[WIDTH-1:16]} : post_r_shift_res_s3;
	assign post_r_shift_res_s5 = post_r_shift_num[5] ? {{(32){post_r_shift_extend_msb}}, post_r_shift_res_s4[WIDTH-1:32]} : post_r_shift_res_s4;
end
else begin
	// WIDTH = 16
	assign post_r_shift_res_s4 = post_r_shift_res_s3;
	assign post_r_shift_res_s5 = post_r_shift_res_s4;
end
endgenerate

// Global Inverters to save area.
// FSM_IDLE_ABS: Get the inversed value of x.
// FSM_POST_PROCESS: Get the inversed value of quo_iter.
assign inverter_in[0] = fsm_q[FSM_IDLE_ABS_BIT] ? x_reg : quo_iter_q;
assign inverter_res[0] = -inverter_in[0];
// FSM_IDLE_ABS: Get the inversed value of y.
// FSM_POST_PROCESS: Get the inversed value of quo_m1_iter.
assign inverter_in[1] = fsm_q[FSM_IDLE_ABS_BIT] ? y_reg : quo_m1_iter_q;
assign inverter_res[1] = -inverter_in[1];

// Calculate ABS
assign dividend_sign 	= div_signed_reg & x_reg[WIDTH-1];
assign divisor_sign 	= div_signed_reg & y_reg[WIDTH-1];
assign dividend_abs 	= dividend_sign ? inverter_res[0] : x_reg;
assign divisor_abs 		= divisor_sign ? inverter_res[1] : y_reg;

assign dividend_abs_en 	= div_start_handshaked | fsm_q[FSM_PRE_0_BIT] | fsm_q[FSM_POST_0_BIT];
assign divisor_abs_en  	= div_start_handshaked | fsm_q[FSM_PRE_0_BIT] | fsm_q[FSM_POST_0_BIT];
// In PRE_PROCESS_1, if we find "divisor_eq_zero", we should force quo_sign = 0 -> We can get final_quo = {(WIDTH){1'b1}};
assign quo_sign_en = div_start_handshaked | (fsm_q[FSM_PRE_1_BIT] & divisor_eq_zero);
assign rem_sign_en = div_start_handshaked;
assign quo_sign_d = fsm_q[FSM_IDLE_ABS_BIT] ? (dividend_sign ^ divisor_sign) : 1'b0;
assign rem_sign_d = dividend_sign;

assign dividend_abs_d = 
  ({(WIDTH + 1){fsm_q[FSM_IDLE_ABS_BIT]}} 	& {1'b0, dividend_abs})
| ({(WIDTH + 1){fsm_q[FSM_PRE_0_BIT]}} 		& {1'b0, normalized_dividend})
| ({(WIDTH + 1){fsm_q[FSM_POST_0_BIT]}} 	& nr_rem_nxt[5 +: (WIDTH + 1)]);
assign divisor_abs_d = 
  ({(WIDTH + 1){fsm_q[FSM_IDLE_ABS_BIT]}} 	& {1'b0, divisor_abs})
| ({(WIDTH + 1){fsm_q[FSM_PRE_0_BIT]}} 		& {1'b0, normalized_divisor})
| ({(WIDTH + 1){fsm_q[FSM_POST_0_BIT]}} 	& nr_rem_plus_d_nxt[5 +: (WIDTH + 1)]);

always @(posedge div_clk) begin
	if(dividend_abs_en)
		dividend_abs_q <= dividend_abs_d;
	if(divisor_abs_en)
		divisor_abs_q <= divisor_abs_d;
	if(quo_sign_en)
		quo_sign_q <= quo_sign_d;
	if(rem_sign_en)
		rem_sign_q <= rem_sign_d;
end

// LZC and Normalize
lzc #(
	.WIDTH(WIDTH),
	// 0: trailing zero.
	// 1: leading zero.
	.MODE(1'b1)
) u_lzc_dividend (
	.in_i(dividend_abs_q[WIDTH-1:0]),
	.cnt_o(dividend_lzc[LZC_WIDTH-1:0]),
	.empty_o(dividend_lzc[LZC_WIDTH])
);
lzc #(
	.WIDTH(WIDTH),
	// 0: trailing zero.
	// 1: leading zero.
	.MODE(1'b1)
) u_lzc_divisor (
	.in_i(divisor_abs_q[WIDTH-1:0]),
	.cnt_o(divisor_lzc[LZC_WIDTH-1:0]),
	.empty_o(divisor_lzc[LZC_WIDTH])
);

assign normalized_dividend = dividend_abs_q[WIDTH-1:0] << dividend_lzc[LZC_WIDTH-1:0];
assign normalized_divisor  = divisor_abs_q [WIDTH-1:0] << divisor_lzc [LZC_WIDTH-1:0];
assign dividend_lzc_en = fsm_q[FSM_PRE_0_BIT];
assign divisor_lzc_en = fsm_q[FSM_PRE_0_BIT];
assign dividend_lzc_d = dividend_lzc;
assign divisor_lzc_d = divisor_lzc;

always @(posedge div_clk) begin
	if(dividend_lzc_en)
		dividend_lzc_q <= dividend_lzc_d;
	if(divisor_lzc_en)
		divisor_lzc_q <= divisor_lzc_d;
end

// Choose the parameters for CMP, according to the value of the normalized_d[(WIDTH - 2) -: 3]
assign qds_para_neg_1_en = fsm_q[FSM_PRE_1_BIT];
// For "normalized_d[(WIDTH - 2) -: 3]",
// 000: m[-1] = -13, -m[-1] = +13 = 00_1101 -> ext(-m[-1]) = 00_11010
// 001: m[-1] = -15, -m[-1] = +15 = 00_1111 -> ext(-m[-1]) = 00_11110
// 010: m[-1] = -16, -m[-1] = +16 = 01_0000 -> ext(-m[-1]) = 01_00000
// 011: m[-1] = -17, -m[-1] = +17 = 01_0001 -> ext(-m[-1]) = 01_00010
// 100: m[-1] = -19, -m[-1] = +19 = 01_0011 -> ext(-m[-1]) = 01_00110
// 101: m[-1] = -20, -m[-1] = +20 = 01_0100 -> ext(-m[-1]) = 01_01000
// 110: m[-1] = -22, -m[-1] = +22 = 01_0110 -> ext(-m[-1]) = 01_01100
// 111: m[-1] = -24, -m[-1] = +24 = 01_1000 -> ext(-m[-1]) = 01_10000
// We need to use 5-bit reg.
assign qds_para_neg_1_d = 
  ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 5'b0_1101)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 5'b0_1111)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 5'b1_0000)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 5'b1_0010)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 5'b1_0011)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 5'b1_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 5'b1_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 5'b1_1000);

assign qds_para_neg_0_en = fsm_q[FSM_PRE_1_BIT];
// For "normalized_d[(WIDTH - 2) -: 3]",
// 000: m[-0] = -4, -m[-0] = +4 = 000_0100
// 001: m[-0] = -6, -m[-0] = +6 = 000_0110
// 010: m[-0] = -6, -m[-0] = +6 = 000_0110
// 011: m[-0] = -6, -m[-0] = +6 = 000_0110
// 100: m[-0] = -6, -m[-0] = +6 = 000_0110
// 101: m[-0] = -8, -m[-0] = +8 = 000_1000
// 110: m[-0] = -8, -m[-0] = +8 = 000_1000
// 111: m[-0] = -8, -m[-0] = +8 = 000_1000
// We need to use 3-bit reg.
assign qds_para_neg_0_d = 
  ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 3'b010)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 3'b011)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 3'b011)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 3'b011)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 3'b011)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 3'b100)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 3'b100)
| ({(3){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 3'b100);

assign qds_para_pos_1_en = fsm_q[FSM_PRE_1_BIT];
// For "normalized_d[(WIDTH - 2) -: 3]",
// 000: m[+1] = +4, -m[+1] = -4 = 111_1100
// 001: m[+1] = +4, -m[+1] = -4 = 111_1100
// 010: m[+1] = +4, -m[+1] = -4 = 111_1100
// 011: m[+1] = +4, -m[+1] = -4 = 111_1100
// 100: m[+1] = +6, -m[+1] = -6 = 111_1010
// 101: m[+1] = +6, -m[+1] = -6 = 111_1010
// 110: m[+1] = +6, -m[+1] = -6 = 111_1010
// 111: m[+1] = +8, -m[+1] = -8 = 111_1000
assign qds_para_pos_1_d = 
  ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 2'b10)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 2'b10)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 2'b10)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 2'b10)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 2'b01)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 2'b01)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 2'b01)
| ({(2){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 2'b00);

assign qds_para_pos_2_en = fsm_q[FSM_PRE_1_BIT];
// For "normalized_d[(WIDTH - 2) -: 3]",
// 000: m[+2] = +12, -m[+2] = -12 = 11_0100 -> ext(-m[+2]) = 11_01000
// 001: m[+2] = +14, -m[+2] = -14 = 11_0010 -> ext(-m[+2]) = 11_00100
// 010: m[+2] = +15, -m[+2] = -15 = 11_0001 -> ext(-m[+2]) = 11_00010
// 011: m[+2] = +16, -m[+2] = -16 = 11_0000 -> ext(-m[+2]) = 11_00000
// 100: m[+2] = +18, -m[+2] = -18 = 10_1110 -> ext(-m[+2]) = 10_11100
// 101: m[+2] = +20, -m[+2] = -20 = 10_1100 -> ext(-m[+2]) = 10_11000
// 110: m[+2] = +22, -m[+2] = -22 = 10_1010 -> ext(-m[+2]) = 10_10100
// 111: m[+2] = +22, -m[+2] = -22 = 10_1010 -> ext(-m[+2]) = 10_10100
assign qds_para_pos_2_d = 
  ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 5'b1_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 5'b1_0010)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 5'b1_0001)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 5'b1_0000)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 5'b0_1110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 5'b0_1100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 5'b0_1010)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 5'b0_1010);

assign special_divisor_en = fsm_q[FSM_PRE_1_BIT];
assign special_divisor_d = (divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000) | (divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100);
always @(posedge div_clk) begin
	if(qds_para_neg_1_en)
		qds_para_neg_1_q <= qds_para_neg_1_d;
	if(qds_para_neg_0_en)
		qds_para_neg_0_q <= qds_para_neg_0_d;
	if(qds_para_pos_1_en)
		qds_para_pos_1_q <= qds_para_pos_1_d;
	if(qds_para_pos_2_en)
		qds_para_pos_2_q <= qds_para_pos_2_d;
	if(special_divisor_en)
		special_divisor_q <= special_divisor_d;
end

// Get iter_num, and some initial value for different regs.
assign lzc_diff_slow = {1'b0, divisor_lzc[0 +: LZC_WIDTH]} - {1'b0, dividend_lzc[0 +: LZC_WIDTH]};
assign lzc_diff_fast = {1'b0, divisor_lzc_q[0 +: LZC_WIDTH]} - {1'b0, dividend_lzc_q[0 +: LZC_WIDTH]};

// Make sure "dividend_too_small" is the "Q" of a Reg -> The timing could be improved.
assign dividend_too_small_en = fsm_q[FSM_PRE_0_BIT];
assign dividend_too_small_d = lzc_diff_slow[LZC_WIDTH] | dividend_lzc[LZC_WIDTH];
always @(posedge div_clk)
	if(dividend_too_small_en)
		dividend_too_small_q <= dividend_too_small_d;

assign divisor_eq_zero = divisor_lzc_q[LZC_WIDTH];
assign divisor_eq_one = (divisor_lzc[LZC_WIDTH-1:0] == {(LZC_WIDTH){1'b1}});
// iter_num = ceil((lzc_diff + 2) / 4);
// Take "WIDTH = 32" as an example, lzc_diff = 
//  0 -> iter_num = 1, actual_r_shift_num = 2;
//  1 -> iter_num = 1, actual_r_shift_num = 1;
//  2 -> iter_num = 1, actual_r_shift_num = 0;
//  3 -> iter_num = 2, actual_r_shift_num = 3;
//  4 -> iter_num = 2, actual_r_shift_num = 2;
//  5 -> iter_num = 2, actual_r_shift_num = 1;
//  6 -> iter_num = 2, actual_r_shift_num = 0;
// ...
// 28 -> iter_num = 8, actual_r_shift_num = 2;
// 29 -> iter_num = 8, actual_r_shift_num = 1;
// 30 -> iter_num = 8, actual_r_shift_num = 0;
// 31 -> iter_num = 9, actual_r_shift_num = 3, avoid this !!!!
// Therefore, max(iter_num) = 8 -> We only need "3-bit Reg" to remember the "iter_num".
// If (lzc_diff == 31) -> Q = x, R = 0.
assign no_iter_needed_en = fsm_q[FSM_PRE_0_BIT];
assign no_iter_needed_d = divisor_eq_one & dividend_abs_q[WIDTH-1];
always @(posedge div_clk)
	if(no_iter_needed_en)
		no_iter_needed_q <= no_iter_needed_d;

// TO save a FA, use "lzc_diff[1:0]" to express "r_shift_num";
assign r_shift_num = lzc_diff_fast[1:0];
assign rem_sum_normal_init_value = {
	3'b0, 
	  {(WIDTH + 3){r_shift_num == 2'd0}} & {2'b0, 	dividend_abs_q[WIDTH-1:0], 1'b0	}
	| {(WIDTH + 3){r_shift_num == 2'd1}} & {1'b0, 	dividend_abs_q[WIDTH-1:0], 2'b0	}
	| {(WIDTH + 3){r_shift_num == 2'd2}} & {		dividend_abs_q[WIDTH-1:0], 3'b0	}
	| {(WIDTH + 3){r_shift_num == 2'd3}} & {3'b0,	dividend_abs_q[WIDTH-1:0]		}
};
assign rem_carry_init_value = {(ITN_W){1'b0}};
// divisor_eq_zero/dividend_too_small: Put the dividend at the suitable position. So we can get the correct R in POST_PROCESS_1.
assign rem_sum_init_value = (dividend_too_small_q | divisor_eq_zero) ? {1'b0, post_r_shift_res_s5, 5'b0} : no_iter_needed_q ? {(ITN_W){1'b0}} : 
rem_sum_normal_init_value;

// For "rem_sum_normal_init_value = (normalized_dividend >> 2 >> r_shift_num)", the decimal point is between "[ITN_W-1]" and "[ITN_W-2]".
// According to the paper, we should use "(4 * rem_sum_normal_init_value)_trunc_1_4" to choose the 1st quo.
assign pre_rem_trunc_1_4 = {1'b0, rem_sum_normal_init_value[(ITN_W - 4) -: 4]};
// For "normalized_d[(WIDTH - 2) -: 3]",
// 000: m[+1] =  +4 = 0_0100;
// 001: m[+1] =  +4 = 0_0100;
// 010: m[+1] =  +4 = 0_0100;
// 011: m[+1] =  +4 = 0_0100;
// 100: m[+1] =  +6 = 0_0110;
// 101: m[+1] =  +6 = 0_0110;
// 110: m[+1] =  +6 = 0_0110;
// 111: m[+1] =  +8 = 0_1000;
// =============================
// 000: m[+2] = +12 = 0_1100;
// 001: m[+2] = +14 = 0_1110;
// 010: m[+2] = +15 = 0_1111;
// 011: m[+2] = +16 = 1_0000;
// 100: m[+2] = +18 = 1_0010;
// 101: m[+2] = +20 = 1_0100;
// 110: m[+2] = +22 = 1_0110;
// 111: m[+2] = +22 = 1_0110;
// So we need to do 5-bit cmp to get the 1st quo.
assign pre_m_pos_1 = 
  ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 5'b0_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 5'b0_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 5'b0_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 5'b0_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 5'b0_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 5'b0_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 5'b0_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 5'b0_1000);
assign pre_m_pos_2 = 
  ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b000}} & 5'b0_1100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b001}} & 5'b0_1110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b010}} & 5'b0_1111)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b011}} & 5'b1_0000)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b100}} & 5'b1_0010)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b101}} & 5'b1_0100)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b110}} & 5'b1_0110)
| ({(5){divisor_abs_q[(WIDTH - 2) -: 3] == 3'b111}} & 5'b1_0110);
// REM must be positive in PRE_PROCESS_1, so we only need to compare it with m[+1]/m[+2]. The 5-bit CMP should be fast enough.
assign pre_cmp_res = {(pre_rem_trunc_1_4 >= pre_m_pos_1), (pre_rem_trunc_1_4 >= pre_m_pos_2)};
assign prev_quo_digit_init_value = pre_cmp_res[0] ? QUO_ONEHOT_POS_2 : pre_cmp_res[1] ? QUO_ONEHOT_POS_1 : QUO_ONEHOT_ZERO;
assign prev_quo_digit_en = fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT];
assign prev_quo_digit_d = fsm_q[FSM_PRE_1_BIT] ? prev_quo_digit_init_value : quo_digit_nxt;
always @(posedge div_clk)
	if(prev_quo_digit_en)
		prev_quo_digit_q <= prev_quo_digit_d;

// Let's do SRT ITER !!!!!
r16_block #(
	.WIDTH(WIDTH),
	.ITN_W(ITN_W),
	.QUO_ONEHOT_WIDTH(QUO_ONEHOT_WIDTH)
) u_r16_block (
	.rem_sum_i(rem_sum_q),
	.rem_carry_i(rem_carry_q),
	.rem_sum_o(rem_sum_nxt),
	.rem_carry_o(rem_carry_nxt),
	.divisor_i(divisor_abs_q[WIDTH-1:0]),
	.qds_para_neg_1_i(qds_para_neg_1_q),
	.qds_para_neg_0_i(qds_para_neg_0_q),
	.qds_para_pos_1_i(qds_para_pos_1_q),
	.qds_para_pos_2_i(qds_para_pos_2_q),
	.special_divisor_i(special_divisor_q),
	.quo_iter_i(quo_iter_q),
	.quo_m1_iter_i(quo_m1_iter_q),
	.quo_iter_o(quo_iter_nxt),
	.quo_m1_iter_o(quo_m1_iter_nxt),
	.prev_quo_digit_i(prev_quo_digit_q),
	.quo_digit_o(quo_digit_nxt)
);

assign quo_iter_en 		= fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT] | fsm_q[FSM_POST_0_BIT];
assign quo_m1_iter_en 	= fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT] | fsm_q[FSM_POST_0_BIT];
// When "divisor_eq_zero", the final Q should be ALL'1s
assign quo_iter_d = fsm_q[FSM_PRE_1_BIT] ? (divisor_eq_zero ? {(WIDTH){1'b1}} : no_iter_needed_q ? dividend_abs_q[WIDTH-1:0] : {(WIDTH){1'b0}}) : 
(fsm_q[FSM_POST_0_BIT] ? (quo_sign_q ? inverter_res[0] : quo_iter_q) : quo_iter_nxt);
assign quo_m1_iter_d = fsm_q[FSM_PRE_1_BIT] ? {(WIDTH){1'b0}} : (fsm_q[FSM_POST_0_BIT] ? (quo_sign_q ? inverter_res[1] : quo_m1_iter_q) : quo_m1_iter_nxt);
always @(posedge div_clk) begin
	if(quo_iter_en)
		quo_iter_q <= quo_iter_d;
	if(quo_m1_iter_en)
		quo_m1_iter_q <= quo_m1_iter_d;
end

assign final_iter = (iter_num_q == {(LZC_WIDTH - 2){1'b0}});
assign iter_num_en = fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT];
assign iter_num_d = fsm_q[FSM_PRE_1_BIT] ? (lzc_diff_fast[LZC_WIDTH - 1:2] + {{(LZC_WIDTH - 3){1'b0}}, &lzc_diff_fast[1:0]}) : 
(iter_num_q - {{(LZC_WIDTH - 3){1'b0}}, 1'b1});
always @(posedge div_clk)
	if(iter_num_en)
		iter_num_q <= iter_num_d;

assign rem_sum_en 		= fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT];
assign rem_sum_d	 	= fsm_q[FSM_PRE_1_BIT] ? rem_sum_init_value : rem_sum_nxt;
assign rem_carry_en 	= fsm_q[FSM_PRE_1_BIT] | fsm_q[FSM_ITER_BIT];
assign rem_carry_d 		= fsm_q[FSM_PRE_1_BIT] ? rem_carry_init_value : rem_carry_nxt;
always @(posedge div_clk) begin
	if(rem_sum_en)
		rem_sum_q <= rem_sum_d;
	if(rem_carry_en)
		rem_carry_q <= rem_carry_d;
end

// Post Process
// If(rem <= 0), 
// rem = (-rem_sum) + (-rem_carry) = ~rem_sum + ~rem_carry + 2'b10;
// If(rem <= 0), 
// rem_plus_d = ~rem_sum + ~rem_carry + ~normalized_d + 2'b11;
assign nr_rem_nxt = 
  ({(ITN_W){rem_sign_q}} ^ rem_sum_q)
+ ({(ITN_W){rem_sign_q}} ^ rem_carry_q)
+ {{(ITN_W - 2){1'b0}}, rem_sign_q, 1'b0};

assign nr_rem_plus_d_nxt = 
  ({(ITN_W){rem_sign_q}} ^ rem_sum_q)
+ ({(ITN_W){rem_sign_q}} ^ rem_carry_q)
+ ({(ITN_W){rem_sign_q}} ^ {1'b0, divisor_abs_q[WIDTH-1:0], 5'b0})
+ {{(ITN_W - 2){1'b0}}, rem_sign_q, rem_sign_q};

assign nr_rem 			= dividend_abs_q;
assign nr_rem_plus_d 	= divisor_abs_q;
assign nr_rem_is_zero 	= ~(|nr_rem);
// Let's assume:
// quo/quo_pre is the ABS value.
// If (rem >= 0), 
// need_corr = 0 <-> "rem_pre" belongs to [ 0, +D), quo = quo_pre - 0, rem = (rem_pre + 0) >> divisor_lzc;
// need_corr = 1 <-> "rem_pre" belongs to (-D,  0), quo = quo_pre - 1, rem = (rem_pre + D) >> divisor_lzc;
// If (rem <= 0), 
// need_corr = 0 <-> "rem_pre" belongs to (-D,  0], quo = quo_pre - 0, rem = (rem_pre - 0) >> divisor_lzc;
// need_corr = 1 <-> "rem_pre" belongs to ( 0, +D), quo = quo_pre - 1, rem = (rem_pre - D) >> divisor_lzc;
assign need_corr = (~divisor_eq_zero & ~no_iter_needed_q) & (rem_sign_q ? (~nr_rem[WIDTH] & ~nr_rem_is_zero) : nr_rem[WIDTH]);
assign pre_shifted_rem = need_corr ? nr_rem_plus_d : nr_rem;
assign final_rem = post_r_shift_res_s5;
assign final_quo = need_corr ? quo_m1_iter_q : quo_iter_q;

// output signals
assign complete = fsm_q[FSM_POST_1_BIT];
assign s = final_quo;
assign r = final_rem;


endmodule