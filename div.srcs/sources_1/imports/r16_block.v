// Overlap 2 R4 blocks to form the R16 block.

module r16_block #(
	parameter WIDTH = 32,
	// ITN = InTerNal
	parameter ITN_W = 1 + WIDTH + 2 + 3,
	parameter QUO_ONEHOT_WIDTH = 5
)(
	input  [ITN_W-1:0] rem_sum_i,
	input  [ITN_W-1:0] rem_carry_i,
	output [ITN_W-1:0] rem_sum_o,
	output [ITN_W-1:0] rem_carry_o,
	input  [WIDTH-1:0] divisor_i,
	input  [5-1:0] qds_para_neg_1_i,
	input  [3-1:0] qds_para_neg_0_i,
	input  [2-1:0] qds_para_pos_1_i,
	input  [5-1:0] qds_para_pos_2_i,
	input  special_divisor_i,
	input  [WIDTH-1:0] quo_iter_i,
	input  [WIDTH-1:0] quo_m1_iter_i,
	output [WIDTH-1:0] quo_iter_o,
	output [WIDTH-1:0] quo_m1_iter_o,
	input  [QUO_ONEHOT_WIDTH-1:0] prev_quo_digit_i,
	output [QUO_ONEHOT_WIDTH-1:0] quo_digit_o
);

// localparams
localparam QUO_NEG_2 = 0;
localparam QUO_NEG_1 = 1;
localparam QUO_ZERO  = 2;
localparam QUO_POS_1 = 3;
localparam QUO_POS_2 = 4;

// signals
// sd = sign_detector
wire [(ITN_W + 4)-1:0] rem_sum_mul_16 [2-1:0];
wire [(ITN_W + 4)-1:0] rem_carry_mul_16 [2-1:0];
wire [7-1:0] rem_sum_mul_16_trunc_2_5 [2-1:0];
wire [7-1:0] rem_carry_mul_16_trunc_2_5 [2-1:0];
wire [7-1:0] rem_sum_mul_16_trunc_3_4 [2-1:0];
wire [7-1:0] rem_carry_mul_16_trunc_3_4 [2-1:0];

wire [ITN_W-1:0] csa_x1 [2-1:0];
wire [ITN_W-1:0] csa_x2 [2-1:0];
wire [ITN_W-1:0] csa_x3 [2-1:0];
wire [2-1:0] csa_carry_unused;
wire [ITN_W-1:0] rem_sum [2-1:0];
wire [ITN_W-1:0] rem_carry [2-1:0];

// Since we need to do "16 * rem_sum + 16 * rem_carry - m[i] - 4 * q * D" (i = -1, 0, +1, +2) to select the next quo,
// so we choose to remember the inversed value of parameters described in the paper.
wire [7-1:0] para_m_neg_1;
wire [7-1:0] para_m_neg_0;
wire [7-1:0] para_m_pos_1;
wire [7-1:0] para_m_pos_2;
wire [7-1:0] para_m_neg_1_q_s0_neg_2;
wire [7-1:0] para_m_neg_0_q_s0_neg_2;
wire [7-1:0] para_m_pos_1_q_s0_neg_2;
wire [7-1:0] para_m_pos_2_q_s0_neg_2;
wire [7-1:0] para_m_neg_1_q_s0_neg_1;
wire [7-1:0] para_m_neg_0_q_s0_neg_1;
wire [7-1:0] para_m_pos_1_q_s0_neg_1;
wire [7-1:0] para_m_pos_2_q_s0_neg_1;
wire [7-1:0] para_m_neg_1_q_s0_pos_0;
wire [7-1:0] para_m_neg_0_q_s0_pos_0;
wire [7-1:0] para_m_pos_1_q_s0_pos_0;
wire [7-1:0] para_m_pos_2_q_s0_pos_0;
wire [7-1:0] para_m_neg_1_q_s0_pos_1;
wire [7-1:0] para_m_neg_0_q_s0_pos_1;
wire [7-1:0] para_m_pos_1_q_s0_pos_1;
wire [7-1:0] para_m_pos_2_q_s0_pos_1;
wire [7-1:0] para_m_neg_1_q_s0_pos_2;
wire [7-1:0] para_m_neg_0_q_s0_pos_2;
wire [7-1:0] para_m_pos_1_q_s0_pos_2;
wire [7-1:0] para_m_pos_2_q_s0_pos_2;

wire [QUO_ONEHOT_WIDTH-1:0] quo_digit_s0;
wire [QUO_ONEHOT_WIDTH-1:0] quo_digit_s1;
wire [WIDTH-1:0] quo_iter_s0;
wire [WIDTH-1:0] quo_iter_s1;
wire [WIDTH-1:0] quo_m1_iter_s0;
wire [WIDTH-1:0] quo_m1_iter_s1;

wire [ITN_W-1:0] divisor;
wire [(ITN_W + 2)-1:0] divisor_mul_4;
wire [(ITN_W + 2)-1:0] divisor_mul_8;
wire [(ITN_W + 2)-1:0] divisor_mul_neg_4;
wire [(ITN_W + 2)-1:0] divisor_mul_neg_8;
wire [7-1:0] divisor_mul_4_trunc_2_5;
wire [7-1:0] divisor_mul_4_trunc_3_4;
wire [7-1:0] divisor_mul_8_trunc_2_5;
wire [7-1:0] divisor_mul_8_trunc_3_4;
wire [7-1:0] divisor_mul_neg_4_trunc_2_5;
wire [7-1:0] divisor_mul_neg_4_trunc_3_4;
wire [7-1:0] divisor_mul_neg_8_trunc_2_5;
wire [7-1:0] divisor_mul_neg_8_trunc_3_4;
wire [7-1:0] divisorfor_sd_trunc_2_5;
wire [7-1:0] divisorfor_sd_trunc_3_4;

wire sd_m_neg_1_sign_s0;
wire sd_m_neg_0_sign_s0;
wire sd_m_pos_1_sign_s0;
wire sd_m_pos_2_sign_s0;
wire sd_m_neg_1_sign_s1;
wire sd_m_neg_0_sign_s1;
wire sd_m_pos_1_sign_s1;
wire sd_m_pos_2_sign_s1;
wire sd_m_neg_1_q_s0_neg_2_sign;
wire sd_m_neg_0_q_s0_neg_2_sign;
wire sd_m_pos_1_q_s0_neg_2_sign;
wire sd_m_pos_2_q_s0_neg_2_sign;
wire sd_m_neg_1_q_s0_neg_1_sign;
wire sd_m_neg_0_q_s0_neg_1_sign;
wire sd_m_pos_1_q_s0_neg_1_sign;
wire sd_m_pos_2_q_s0_neg_1_sign;
wire sd_m_neg_1_q_s0_pos_0_sign;
wire sd_m_neg_0_q_s0_pos_0_sign;
wire sd_m_pos_1_q_s0_pos_0_sign;
wire sd_m_pos_2_q_s0_pos_0_sign;
wire sd_m_neg_1_q_s0_pos_1_sign;
wire sd_m_neg_0_q_s0_pos_1_sign;
wire sd_m_pos_1_q_s0_pos_1_sign;
wire sd_m_pos_2_q_s0_pos_1_sign;
wire sd_m_neg_1_q_s0_pos_2_sign;
wire sd_m_neg_0_q_s0_pos_2_sign;
wire sd_m_pos_1_q_s0_pos_2_sign;
wire sd_m_pos_2_q_s0_pos_2_sign;

// main codes
// After "* 16" operation, the decimal point is still between "[ITN_W-1]" and "[ITN_W-2]".
assign rem_sum_mul_16[0] = {rem_sum_i, 4'b0};
assign rem_carry_mul_16[0] = {rem_carry_i, 4'b0};

// We need "2 integer bits, 5 fraction bits"/"3 integer bits, 4 fraction bits" for SD.
assign rem_sum_mul_16_trunc_2_5[0] = rem_sum_mul_16[0][(ITN_W    ) -: 7];
assign rem_sum_mul_16_trunc_3_4[0] = rem_sum_mul_16[0][(ITN_W + 1) -: 7];
assign rem_carry_mul_16_trunc_2_5[0] = rem_carry_mul_16[0][(ITN_W    ) -: 7];
assign rem_carry_mul_16_trunc_3_4[0] = rem_carry_mul_16[0][(ITN_W + 1) -: 7];

// Get the parameters for CMP.
assign para_m_neg_1 = {1'b0, qds_para_neg_1_i, 1'b0};
assign para_m_neg_0 = {3'b0, qds_para_neg_0_i, special_divisor_i};
assign para_m_pos_1 = {4'b1111, qds_para_pos_1_i, special_divisor_i};
assign para_m_pos_2 = {1'b1, qds_para_pos_2_i, 1'b0};

// Calculate "-4 * q * D" for CMP.
assign divisor = {1'b0, divisor_i, 5'b0};
assign divisor_mul_4 = {divisor, 2'b0};
assign divisor_mul_8 = {divisor[ITN_W-2:0], 3'b0};

// Using "~" is enough here.
assign divisor_mul_neg_4 = ~divisor_mul_4;
assign divisor_mul_neg_8 = ~divisor_mul_8;
assign divisor_mul_4_trunc_2_5 = divisor_mul_4[(ITN_W	 ) -: 7];
assign divisor_mul_4_trunc_3_4 = divisor_mul_4[(ITN_W + 1) -: 7];
assign divisor_mul_8_trunc_2_5 = divisor_mul_8[(ITN_W	 ) -: 7];
assign divisor_mul_8_trunc_3_4 = divisor_mul_8[(ITN_W + 1) -: 7];
assign divisor_mul_neg_4_trunc_2_5 = divisor_mul_neg_4[(ITN_W	 ) -: 7];
assign divisor_mul_neg_4_trunc_3_4 = divisor_mul_neg_4[(ITN_W + 1) -: 7];
assign divisor_mul_neg_8_trunc_2_5 = divisor_mul_neg_8[(ITN_W	 ) -: 7];
assign divisor_mul_neg_8_trunc_3_4 = divisor_mul_neg_8[(ITN_W + 1) -: 7];

assign divisorfor_sd_trunc_2_5 = 
  ({(7){prev_quo_digit_i[QUO_NEG_2]}} & divisor_mul_8_trunc_2_5)
| ({(7){prev_quo_digit_i[QUO_NEG_1]}} & divisor_mul_4_trunc_2_5)
| ({(7){prev_quo_digit_i[QUO_POS_1]}} & divisor_mul_neg_4_trunc_2_5)
| ({(7){prev_quo_digit_i[QUO_POS_2]}} & divisor_mul_neg_8_trunc_2_5);
assign divisorfor_sd_trunc_3_4 = 
  ({(7){prev_quo_digit_i[QUO_NEG_2]}} & divisor_mul_8_trunc_3_4)
| ({(7){prev_quo_digit_i[QUO_NEG_1]}} & divisor_mul_4_trunc_3_4)
| ({(7){prev_quo_digit_i[QUO_POS_1]}} & divisor_mul_neg_4_trunc_3_4)
| ({(7){prev_quo_digit_i[QUO_POS_2]}} & divisor_mul_neg_8_trunc_3_4);

// Calculate sign and code the res.
radix_4_sign_detector
u_sd_m_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[0]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[0]),
	.parameter_i(para_m_neg_1),
	.divisor_i(divisorfor_sd_trunc_2_5),
	.sign_o(sd_m_neg_1_sign_s0)
);
radix_4_sign_detector
u_sd_m_neg_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[0]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[0]),
	.parameter_i(para_m_neg_0),
	.divisor_i(divisorfor_sd_trunc_3_4),
	.sign_o(sd_m_neg_0_sign_s0)
);
radix_4_sign_detector
u_sd_m_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[0]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[0]),
	.parameter_i(para_m_pos_1),
	.divisor_i(divisorfor_sd_trunc_3_4),
	.sign_o(sd_m_pos_1_sign_s0)
);
radix_4_sign_detector
u_sd_m_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[0]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[0]),
	.parameter_i(para_m_pos_2),
	.divisor_i(divisorfor_sd_trunc_2_5),
	.sign_o(sd_m_pos_2_sign_s0)
);
radix_4_sign_coder
u_coder_s0 (
	.sd_m_neg_1_sign_i(sd_m_neg_1_sign_s0),
	.sd_m_neg_0_sign_i(sd_m_neg_0_sign_s0),
	.sd_m_pos_1_sign_i(sd_m_pos_1_sign_s0),
	.sd_m_pos_2_sign_i(sd_m_pos_2_sign_s0),
	.quot_o(quo_digit_s0)
);
// ================================================================================================================================================
// On the Fly Conversion (OFC/OTFC).
// ================================================================================================================================================
assign quo_iter_s0 = 
  ({(WIDTH){prev_quo_digit_i[QUO_POS_2]}} & {quo_iter_i		[WIDTH-3:0], 2'b10})
| ({(WIDTH){prev_quo_digit_i[QUO_POS_1]}} & {quo_iter_i		[WIDTH-3:0], 2'b01})
| ({(WIDTH){prev_quo_digit_i[QUO_ZERO ]}} & {quo_iter_i		[WIDTH-3:0], 2'b00})
| ({(WIDTH){prev_quo_digit_i[QUO_NEG_1]}} & {quo_m1_iter_i	[WIDTH-3:0], 2'b11})
| ({(WIDTH){prev_quo_digit_i[QUO_NEG_2]}} & {quo_m1_iter_i	[WIDTH-3:0], 2'b10});
assign quo_m1_iter_s0 = 
  ({(WIDTH){prev_quo_digit_i[QUO_POS_2]}} & {quo_iter_i		[WIDTH-3:0], 2'b01})
| ({(WIDTH){prev_quo_digit_i[QUO_POS_1]}} & {quo_iter_i		[WIDTH-3:0], 2'b00})
| ({(WIDTH){prev_quo_digit_i[QUO_ZERO ]}} & {quo_m1_iter_i	[WIDTH-3:0], 2'b11})
| ({(WIDTH){prev_quo_digit_i[QUO_NEG_1]}} & {quo_m1_iter_i	[WIDTH-3:0], 2'b10})
| ({(WIDTH){prev_quo_digit_i[QUO_NEG_2]}} & {quo_m1_iter_i	[WIDTH-3:0], 2'b01});
// In the Retiming Architecture, OFC should not be the critical path.
assign quo_iter_s1 = 
  ({(WIDTH){quo_digit_s0[QUO_POS_2]}} & {quo_iter_s0		[WIDTH-3:0], 2'b10})
| ({(WIDTH){quo_digit_s0[QUO_POS_1]}} & {quo_iter_s0		[WIDTH-3:0], 2'b01})
| ({(WIDTH){quo_digit_s0[QUO_ZERO ]}} & {quo_iter_s0		[WIDTH-3:0], 2'b00})
| ({(WIDTH){quo_digit_s0[QUO_NEG_1]}} & {quo_m1_iter_s0		[WIDTH-3:0], 2'b11})
| ({(WIDTH){quo_digit_s0[QUO_NEG_2]}} & {quo_m1_iter_s0		[WIDTH-3:0], 2'b10});
assign quo_m1_iter_s1 = 
  ({(WIDTH){quo_digit_s0[QUO_POS_2]}} & {quo_iter_s0		[WIDTH-3:0], 2'b01})
| ({(WIDTH){quo_digit_s0[QUO_POS_1]}} & {quo_iter_s0		[WIDTH-3:0], 2'b00})
| ({(WIDTH){quo_digit_s0[QUO_ZERO ]}} & {quo_m1_iter_s0		[WIDTH-3:0], 2'b11})
| ({(WIDTH){quo_digit_s0[QUO_NEG_1]}} & {quo_m1_iter_s0		[WIDTH-3:0], 2'b10})
| ({(WIDTH){quo_digit_s0[QUO_NEG_2]}} & {quo_m1_iter_s0		[WIDTH-3:0], 2'b01});

assign csa_x1[0] = {rem_sum_i  [0 +: (ITN_W - 2)], 2'b0};
assign csa_x2[0] = {rem_carry_i[0 +: (ITN_W - 2)], 2'b0};
assign csa_x3[0] = 
  ({(ITN_W){prev_quo_digit_i[QUO_NEG_2]}} & {divisor_i, 6'b0})
| ({(ITN_W){prev_quo_digit_i[QUO_NEG_1]}} & {1'b0, divisor_i, 5'b0})
| ({(ITN_W){prev_quo_digit_i[QUO_POS_1]}} & ~{1'b0, divisor_i, 5'b0})
| ({(ITN_W){prev_quo_digit_i[QUO_POS_2]}} & ~{divisor_i, 6'b0});
compressor_3_2 #(
	.WIDTH(ITN_W)
) u_csa_s0 (
	.x1(csa_x1[0]),
	.x2(csa_x2[0]),
	.x3(csa_x3[0]),
	.sum_o(rem_sum[0]),
	.carry_o({rem_carry[0][1 +: (ITN_W - 1)], csa_carry_unused[0]})
);
assign rem_carry[0][0] = prev_quo_digit_i[QUO_POS_1] | prev_quo_digit_i[QUO_POS_2];

// Similiar operations for stage[1].
assign rem_sum_mul_16[1] = {rem_sum[0], 4'b0};
assign rem_carry_mul_16[1] = {rem_carry[0], 4'b0};
assign rem_sum_mul_16_trunc_2_5[1] = rem_sum_mul_16[1][(ITN_W    ) -: 7];
assign rem_sum_mul_16_trunc_3_4[1] = rem_sum_mul_16[1][(ITN_W + 1) -: 7];
assign rem_carry_mul_16_trunc_2_5[1] = rem_carry_mul_16[1][(ITN_W    ) -: 7];
assign rem_carry_mul_16_trunc_3_4[1] = rem_carry_mul_16[1][(ITN_W + 1) -: 7];

// Assume "quo_digit_s0 = -2". Then calculate "quo_digit_s1" speculativly.
radix_4_sign_detector
u_sd_m_neg_1_q_s0_neg_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_neg_1),
	.divisor_i(divisor_mul_8_trunc_2_5),
	.sign_o(sd_m_neg_1_q_s0_neg_2_sign)
);
radix_4_sign_detector
u_sd_m_neg_0_q_s0_neg_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_neg_0),
	.divisor_i(divisor_mul_8_trunc_3_4),
	.sign_o(sd_m_neg_0_q_s0_neg_2_sign)
);
radix_4_sign_detector
u_sd_m_pos_1_q_s0_neg_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_pos_1),
	.divisor_i(divisor_mul_8_trunc_3_4),
	.sign_o(sd_m_pos_1_q_s0_neg_2_sign)
);
radix_4_sign_detector
u_sd_m_pos_2_q_s0_neg_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_pos_2),
	.divisor_i(divisor_mul_8_trunc_2_5),
	.sign_o(sd_m_pos_2_q_s0_neg_2_sign)
);
// ================================================================================================================================================
// Here we assume "quo_digit_s0 = -1". Then calculate "quo_digit_s1" speculativly.
// ================================================================================================================================================
radix_4_sign_detector
u_sd_m_neg_1_q_s0_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_neg_1),
	.divisor_i(divisor_mul_4_trunc_2_5),
	.sign_o(sd_m_neg_1_q_s0_neg_1_sign)
);
radix_4_sign_detector
u_sd_m_neg_0_q_s0_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_neg_0),
	.divisor_i(divisor_mul_4_trunc_3_4),
	.sign_o(sd_m_neg_0_q_s0_neg_1_sign)
);
radix_4_sign_detector
u_sd_m_pos_1_q_s0_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_pos_1),
	.divisor_i(divisor_mul_4_trunc_3_4),
	.sign_o(sd_m_pos_1_q_s0_neg_1_sign)
);
radix_4_sign_detector
u_sd_m_pos_2_q_s0_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_pos_2),
	.divisor_i(divisor_mul_4_trunc_2_5),
	.sign_o(sd_m_pos_2_q_s0_neg_1_sign)
);

// Assume "quo_digit_s0 = 0". Then calculate "quo_digit_s1" speculativly.
radix_4_sign_detector
u_sd_m_neg_1_q_s0_pos_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_neg_1),
	.divisor_i(7'b0),
	.sign_o(sd_m_neg_1_q_s0_pos_0_sign)
);
radix_4_sign_detector
u_sd_m_neg_0_q_s0_pos_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_neg_0),
	.divisor_i(7'b0),
	.sign_o(sd_m_neg_0_q_s0_pos_0_sign)
);
radix_4_sign_detector
u_sd_m_pos_1_q_s0_pos_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_pos_1),
	.divisor_i(7'b0),
	.sign_o(sd_m_pos_1_q_s0_pos_0_sign)
);
radix_4_sign_detector
u_sd_m_pos_2_q_s0_pos_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_pos_2),
	.divisor_i(7'b0),
	.sign_o(sd_m_pos_2_q_s0_pos_0_sign)
);

// Assume "quo_digit_s0 = +1". Then calculate "quo_digit_s1" speculativly.
radix_4_sign_detector
u_sd_m_neg_1_q_s0_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_neg_1),
	.divisor_i(divisor_mul_neg_4_trunc_2_5),
	.sign_o(sd_m_neg_1_q_s0_pos_1_sign)
);
radix_4_sign_detector
u_sd_m_neg_0_q_s0_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_neg_0),
	.divisor_i(divisor_mul_neg_4_trunc_3_4),
	.sign_o(sd_m_neg_0_q_s0_pos_1_sign)
);
radix_4_sign_detector
u_sd_m_pos_1_q_s0_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_pos_1),
	.divisor_i(divisor_mul_neg_4_trunc_3_4),
	.sign_o(sd_m_pos_1_q_s0_pos_1_sign)
);
radix_4_sign_detector
u_sd_m_pos_2_q_s0_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_pos_2),
	.divisor_i(divisor_mul_neg_4_trunc_2_5),
	.sign_o(sd_m_pos_2_q_s0_pos_1_sign)
);

// Assume "quo_digit_s0 = +2". Then calculate "quo_digit_s1" speculativly.
radix_4_sign_detector
u_sd_m_neg_1_q_s0_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_neg_1),
	.divisor_i(divisor_mul_neg_8_trunc_2_5),
	.sign_o(sd_m_neg_1_q_s0_pos_2_sign)
);
radix_4_sign_detector
u_sd_m_neg_0_q_s0_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_neg_0),
	.divisor_i(divisor_mul_neg_8_trunc_3_4),
	.sign_o(sd_m_neg_0_q_s0_pos_2_sign)
);
radix_4_sign_detector
u_sd_m_pos_1_q_s0_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4[1]),
	.parameter_i(para_m_pos_1),
	.divisor_i(divisor_mul_neg_8_trunc_3_4),
	.sign_o(sd_m_pos_1_q_s0_pos_2_sign)
);
radix_4_sign_detector
u_sd_m_pos_2_q_s0_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5[1]),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5[1]),
	.parameter_i(para_m_pos_2),
	.divisor_i(divisor_mul_neg_8_trunc_2_5),
	.sign_o(sd_m_pos_2_q_s0_pos_2_sign)
);

assign sd_m_neg_1_sign_s1 = 
  ({(1){quo_digit_s0[QUO_NEG_2]}} & sd_m_neg_1_q_s0_neg_2_sign)
| ({(1){quo_digit_s0[QUO_NEG_1]}} & sd_m_neg_1_q_s0_neg_1_sign)
| ({(1){quo_digit_s0[QUO_ZERO ]}} & sd_m_neg_1_q_s0_pos_0_sign)
| ({(1){quo_digit_s0[QUO_POS_1]}} & sd_m_neg_1_q_s0_pos_1_sign)
| ({(1){quo_digit_s0[QUO_POS_2]}} & sd_m_neg_1_q_s0_pos_2_sign);
assign sd_m_neg_0_sign_s1 = 
  ({(1){quo_digit_s0[QUO_NEG_2]}} & sd_m_neg_0_q_s0_neg_2_sign)
| ({(1){quo_digit_s0[QUO_NEG_1]}} & sd_m_neg_0_q_s0_neg_1_sign)
| ({(1){quo_digit_s0[QUO_ZERO ]}} & sd_m_neg_0_q_s0_pos_0_sign)
| ({(1){quo_digit_s0[QUO_POS_1]}} & sd_m_neg_0_q_s0_pos_1_sign)
| ({(1){quo_digit_s0[QUO_POS_2]}} & sd_m_neg_0_q_s0_pos_2_sign);
assign sd_m_pos_1_sign_s1 = 
  ({(1){quo_digit_s0[QUO_NEG_2]}} & sd_m_pos_1_q_s0_neg_2_sign)
| ({(1){quo_digit_s0[QUO_NEG_1]}} & sd_m_pos_1_q_s0_neg_1_sign)
| ({(1){quo_digit_s0[QUO_ZERO ]}} & sd_m_pos_1_q_s0_pos_0_sign)
| ({(1){quo_digit_s0[QUO_POS_1]}} & sd_m_pos_1_q_s0_pos_1_sign)
| ({(1){quo_digit_s0[QUO_POS_2]}} & sd_m_pos_1_q_s0_pos_2_sign);
assign sd_m_pos_2_sign_s1 = 
  ({(1){quo_digit_s0[QUO_NEG_2]}} & sd_m_pos_2_q_s0_neg_2_sign)
| ({(1){quo_digit_s0[QUO_NEG_1]}} & sd_m_pos_2_q_s0_neg_1_sign)
| ({(1){quo_digit_s0[QUO_ZERO ]}} & sd_m_pos_2_q_s0_pos_0_sign)
| ({(1){quo_digit_s0[QUO_POS_1]}} & sd_m_pos_2_q_s0_pos_1_sign)
| ({(1){quo_digit_s0[QUO_POS_2]}} & sd_m_pos_2_q_s0_pos_2_sign);

// Before sign_coder_stage[1] begins, we are supposed to get "quo_digit_s0" (think of its delay) -> Only 1 coder is needed for stage[1].
radix_4_sign_coder
u_coder_s1 (
	.sd_m_neg_1_sign_i(sd_m_neg_1_sign_s1),
	.sd_m_neg_0_sign_i(sd_m_neg_0_sign_s1),
	.sd_m_pos_1_sign_i(sd_m_pos_1_sign_s1),
	.sd_m_pos_2_sign_i(sd_m_pos_2_sign_s1),
	.quot_o(quo_digit_s1)
);

assign csa_x1[1] = {rem_sum[0]  [0 +: (ITN_W - 2)], 2'b0};
assign csa_x2[1] = {rem_carry[0][0 +: (ITN_W - 2)], 2'b0};
assign csa_x3[1] = 
  ({(ITN_W){quo_digit_s0[QUO_NEG_2]}} & {divisor_i, 6'b0})
| ({(ITN_W){quo_digit_s0[QUO_NEG_1]}} & {1'b0, divisor_i, 5'b0})
| ({(ITN_W){quo_digit_s0[QUO_POS_1]}} & ~{1'b0, divisor_i, 5'b0})
| ({(ITN_W){quo_digit_s0[QUO_POS_2]}} & ~{divisor_i, 6'b0});
compressor_3_2 #(
	.WIDTH(ITN_W)
) u_csa_s1 (
	.x1(csa_x1[1]),
	.x2(csa_x2[1]),
	.x3(csa_x3[1]),
	.sum_o(rem_sum[1]),
	.carry_o({rem_carry[1][1 +: (ITN_W - 1)], csa_carry_unused[1]})
);
assign rem_carry[1][0] = quo_digit_s0[QUO_POS_1] | quo_digit_s0[QUO_POS_2];

assign rem_sum_o = rem_sum[1];
assign rem_carry_o = rem_carry[1];
assign quo_iter_o = quo_iter_s1;
assign quo_m1_iter_o = quo_m1_iter_s1;
assign quo_digit_o = quo_digit_s1;


endmodule
