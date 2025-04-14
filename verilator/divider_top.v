module divider_top (
    input  div_start,           // Renamed from div
    input  division_signed,     // Renamed from div_signed
    input  [31:0] dividend,     // Renamed from x
    input  [31:0] divisor,      // Renamed from y

    output division_complete,   // Renamed from complete
    output [31:0] quotient,     // Renamed from s
    output [31:0] remainder,    // Renamed from r

    input  div_clk,
    input  resetn
);

    div div_inst (
        .div(div_start),
        .div_signed(division_signed),
        .x(dividend),
        .y(divisor),
        .complete(division_complete),
        .s(quotient),
        .r(remainder),
        .div_clk(div_clk),
        .resetn(resetn)
    );

endmodule
