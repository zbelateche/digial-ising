
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module coupled_cell #(parameter NUM_WEIGHTS = 15,
                      parameter NUM_LUTS    = 1 ) (
		       // Oscillator RST
		       input  wire ising_rstn,

		       // Asynchronous phase IO
	               input  wire lin,
	               input  wire rin,
	               input  wire tin,
	               input  wire bin,
	               output wire lout,
	               output wire rout,
	               output wire tout,
	               output wire bout,

		       // Synchronous AXI write interface
		       input  wire        clk,
		       input  wire        axi_rstn,
                       input  wire        wready,
		       input  wire        wr_addr_match,
		       input  wire        vh,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );
    genvar i;

    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_vh;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_vh_nxt;
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_hv;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_hv_nxt;

    assign rdata = vh ? weight_vh : weight_hv;

    assign weight_vh_nxt = (wready & wr_addr_match &  vh) ? wdata[NUM_WEIGHTS-1:0] :
	                                                    weight_vh              ;
    assign weight_hv_nxt = (wready & wr_addr_match & ~vh) ? wdata[NUM_WEIGHTS-1:0] :
	                                                    weight_hv              ;
    always @(posedge clk) begin
	if (!axi_rstn) begin
      	    weight_hv <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
      	    weight_vh <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
        end else begin
            weight_vh <= weight_vh_nxt;
            weight_hv <= weight_hv_nxt;
        end
    end

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator, and speed it up
    // otherwise.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator, and speed it up
    // otherwise.
  
    assign mismatch_lb  = ~(lin ^ tout);
    assign mismatch_bl  = ~(bin ^ rout);
    assign mismatch_rt  = ~(rin ^ bout);
    assign mismatch_tr  = ~(tin ^ lout);

    // Build our delay lines
    wire [NUM_WEIGHTS-1:0] l_buf;
    wire [NUM_WEIGHTS-1:0] b_buf;
    wire [NUM_WEIGHTS-1:0] r_buf;
    wire [NUM_WEIGHTS-1:0] t_buf;

    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
	wire l_buf_in;
	wire b_buf_in;
	wire r_buf_in;
	wire t_buf_in;

	if (i == 0) begin
            assign l_buf_in = lin;
            assign b_buf_in = bin;
            assign r_buf_in = rin;
            assign t_buf_in = tin;
        end else begin
	    assign l_buf_in = l_buf[i-1];
	    assign b_buf_in = b_buf[i-1];
	    assign r_buf_in = r_buf[i-1];
	    assign t_buf_in = t_buf[i-1];
        end
	
        buffer #(NUM_LUTS) buf_l(.in(l_buf_in), .out(l_buf[i]));
        buffer #(NUM_LUTS) buf_b(.in(b_buf_in), .out(b_buf[i]));
        buffer #(NUM_LUTS) buf_r(.in(r_buf_in), .out(r_buf[i]));
        buffer #(NUM_LUTS) buf_t(.in(t_buf_in), .out(t_buf[i]));
    end endgenerate

    // Tap those delay lines based on weight
    // TODO: Do we need to manually balance these decoder trees?
    wire l_buf_out_ma, l_buf_out_mi;
    wire b_buf_out_ma, b_buf_out_mi;
    wire r_buf_out_ma, r_buf_out_mi;
    wire t_buf_out_ma, t_buf_out_mi;
    assign l_buf_out_ma = l_buf[              weight_vh    ];
    assign l_buf_out_mi = l_buf[NUM_WEIGHTS - weight_vh - 1];
    assign b_buf_out_ma = b_buf[              weight_hv    ];
    assign b_buf_out_mi = b_buf[NUM_WEIGHTS - weight_hv - 1];
    assign r_buf_out_ma = r_buf[              weight_vh    ];
    assign r_buf_out_mi = r_buf[NUM_WEIGHTS - weight_vh - 1];
    assign t_buf_out_ma = t_buf[              weight_hv    ];
    assign t_buf_out_mi = t_buf[NUM_WEIGHTS - weight_hv - 1];

    // Select output based on mismatch status
    wire rout_mis;
    wire tout_mis;
    wire lout_mis;
    wire bout_mis;
    assign rout_mis = mismatch_lb ? l_buf_out_mi : l_buf_out_ma;
    assign tout_mis = mismatch_bl ? b_buf_out_mi : b_buf_out_ma;
    assign lout_mis = mismatch_rt ? r_buf_out_mi : r_buf_out_ma;
    assign bout_mis = mismatch_tr ? t_buf_out_mi : t_buf_out_ma;

    // Prevent glitching: An output should never switch from the current
    // input value, only to that value.
    wire rout_pre;
    wire tout_pre;
    wire lout_pre;
    wire bout_pre;
    assign rout_pre = (rout == lin) ? rout     : rout_mis ;
    assign tout_pre = (tout == bin) ? tout     : tout_mis ;
    assign lout_pre = (lout == rin) ? lout     : lout_mis ;
    assign bout_pre = (bout == tin) ? bout     : bout_mis ;
    
    // When resetting, pass the input through directly
    wire rout_rst;
    wire tout_rst;
    wire lout_rst;
    wire bout_rst;
    assign rout_rst = ising_rstn    ? rout_pre : lin      ;
    assign tout_rst = ising_rstn    ? tout_pre : bin      ;
    assign lout_rst = ising_rstn    ? lout_pre : rin      ;
    assign bout_rst = ising_rstn    ? bout_pre : tin      ;
    
    // One more buffer to keep the output-input
    // feedback loop stable
    buffer #(NUM_LUTS) bufr(.in(rout_rst), .out(rout_int));
    buffer #(NUM_LUTS) buft(.in(tout_rst), .out(tout_int));
    buffer #(NUM_LUTS) bufl(.in(lout_rst), .out(lout_int));
    buffer #(NUM_LUTS) bufb(.in(bout_rst), .out(bout_int));

    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign rout = rout_int;
        assign tout = tout_int;
        assign lout = lout_int;
        assign bout = bout_int;
    `else
        (* dont_touch = "yes" *) LDCE r_latch (.Q(rout), .D(rout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE t_latch (.Q(tout), .D(tout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE l_latch (.Q(lout), .D(lout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE b_latch (.Q(bout), .D(bout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
    `endif

endmodule
