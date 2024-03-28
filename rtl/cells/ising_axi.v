
// AXI-compatible wrapper for Ising machine.
//
// All control registers live here.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "top_ising.v"
`endif

module ising_axi    #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5) (
		     input  wire clk,
		     input  wire axi_rstn,

		     // AXI Read port
		     input  wire        arvalid_q,
		     input  wire [31:0] araddr_q,
		     input  wire        rready,
                     output reg         rvalid,
	             output reg         rresp,	     
		     output reg  [31:0] rdata,

		     // AXI Write port
		     input  wire        wready,
	             input  wire [31:0] wr_addr,
		     input  wire [31:0] wdata
	            );

    wire [ 31:0] phase_read_val;
    assign       phase_sel  = (araddr_q[31:12] == `PHASE_ADDR_MASK );

    wire [31:0]  weight_read_val;
    assign       weight_sel = (araddr_q[31:24] == `WEIGHT_ADDR_MASK);

    // AXI Read Interface
    always @(posedge clk) begin
        if (!axi_rstn) begin
            rvalid <= 0;
            rdata  <= 0;
            rresp  <= 0;
        end
        else if (rvalid && rready) begin
            rvalid <= 0;
            rdata  <= 0;
            rresp  <= 0;
        end
	else if (arvalid_q) begin
            rvalid <= 1;
	    rdata  <= phase_sel  ? phase_read_val            : 
		      weight_sel ? weight_read_val           :
		                   32'hAAAAAAAA              ;
            rresp  <= 0;
        end
    end

    // AXI Write Interface
    reg [31:0] counter_cutoff;
    reg [31:0] counter_max;
    reg [31:0] ising_rstn_cnt;
    
    wire [31:0] counter_cutoff_nxt = (wready & (wr_addr == `CTR_CUTOFF_ADDR)) ?
	                             wdata : counter_cutoff; 
    wire [31:0] counter_max_nxt    = (wready & (wr_addr == `CTR_MAX_ADDR)) ?
	                             wdata : counter_max; 
    wire [31:0] ising_rstn_nxt     = (wready & (wr_addr == `START_ADDR)) ?
	                             wdata : (
				     ising_rstn_cnt != 0 ? ising_rstn_cnt - 1 :
				                           ising_rstn_cnt    ); 
    
    always @(posedge clk) begin
        if (!axi_rstn) begin
            counter_cutoff <= 32'b0;
	    counter_max <= 32'b0;
            ising_rstn_cnt <= 32'b0;
        end
        else begin
            counter_cutoff <= counter_cutoff_nxt;
            counter_max <= counter_max_nxt;
            ising_rstn_cnt <= ising_rstn_nxt;
        end
    end

    wire ising_rstn = (ising_rstn_cnt > 0);

    top_ising   #(.N(N),
	          .NUM_WEIGHTS(NUM_WEIGHTS)) u_top_ising (
                  .clk(clk),
                  .ising_rstn(ising_rstn),
                  .counter_max(counter_max),
                  .counter_cutoff(counter_cutoff),
                  .phase(phase_read_val),
	          .axi_rstn(axi_rstn),
	          .wready(wready),
	          .wr_addr(wr_addr),
	          .wdata(wdata),
		  .rd_addr(araddr_q),
		  .rdata(weight_read_val)
    );

endmodule
