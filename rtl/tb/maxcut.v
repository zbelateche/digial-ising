
`define SIM
`include "../cells/ising_axi.v"

`timescale 1ns/1ps

// Solve the following max-cut problem:
//
//
//         │
//         │
//    E────X──D─────┐
//    │    │  │     │
//    │    │  │     │
// ───X──┐ └──X──┐  C
//    │  │    │  │  │
//    │  │    │  │  │
//    A──X────B──X──┘
//       │       │
//       └───────┘
//
// Expected output:
//     A, C, D same phase
//     B, E    same phase
//

module maxcut_tb();

    reg         clk;
    reg         rstn;
    reg  [31:0] raddr;
    wire [31:0] rdata;
    reg  [31:0] waddr;
    reg  [31:0] wdata;
    reg         wready;
 
    // Create an 8x8 array of coupled cells
    // Cell H is the local field, which is positively coupled with all of the
    // other active cells.
    ising_axi   #(.N(8),
	          .NUM_WEIGHTS(3)) dut(
		  .clk(clk),
		  .axi_rstn(rstn),
                  .arvalid_q(1'b1),
		  .araddr_q(raddr),
		  .rready(1'b0),
		  .rvalid(),
		  .rresp(),
		  .rdata(rdata),
		  .wready(wready),
		  .wr_addr(waddr),
		  .wdata(wdata));


    // Use a clock that's prime to wire delay
    always #51 clk = ~clk;

    integer i;

    initial begin
	$dumpfile("maxcut.vcd");
        $dumpvars(0, maxcut_tb);
	for (i = 0 ; i < 8; i = i+1) begin
            $dumpvars(0, dut.u_top_ising.u_sampler.phase_counters[i]);
            $dumpvars(0, dut.u_top_ising.u_sampler.phase_counters_nxt[i]);
	end

	clk = 0;
	raddr = 32'b0;
	waddr = 32'b0;
	wdata = 32'b0;
        rstn = 1'b0;
	wready = 1'b0;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
	#1
	rstn = 1'b1;

        /////////////////////////////////////////////////////////////
	// Program counters
	
	@(posedge clk);
	#1
	wready = 1'b1;

        @(posedge clk);
	waddr = `CTR_CUTOFF_ADDR;
	wdata = 32'h00000004;

	@(posedge clk);
	waddr = `CTR_MAX_ADDR;
	wdata = 32'h00000008;
        
	/////////////////////////////////////////////////////////////
	// Check weight reset values
	
	@(posedge clk);
	wready = 1'b0;
	
	@(posedge clk);
	raddr = `WEIGHT_ADDR_BASE + (31'd0 << 2) + (31'd1 << 13);
	@(posedge clk);
	#1
	if(rdata[2:0] != 3'b001) $display("!!! AB FAILED !!!"); //A

	/////////////////////////////////////////////////////////////
	// Program initial spins
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd1 << 2) + (32'd1 << 13); //E
	wdata = 32'h00000001;                                     //000
	
	/////////////////////////////////////////////////////////////
	// Program (asymmetric) weights
	
	@(posedge clk);
	wready = 1'b1;

	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd0 << 2) + (32'd1 << 13); //AB
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd1 << 2) + (32'd0 << 13); //AB
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd0 << 2) + (32'd4 << 13); //AE
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd4 << 2) + (32'd0 << 13); //AE
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd0 << 2) + (32'd7 << 13); //AH
	wdata = 32'h00000002;                                     //1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd7 << 2) + (32'd0 << 13); //AH
	wdata = 32'h00000002;                                     //1

	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd1 << 2) + (32'd2 << 13); //BC
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd2 << 2) + (32'd1 << 13); //BC
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd1 << 2) + (32'd3 << 13); //BD
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd3 << 2) + (32'd1 << 13); //BD
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd1 << 2) + (32'd7 << 13); //BH
	wdata = 32'h00000002;                                     //1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd7 << 2) + (32'd1 << 13); //BH
	wdata = 32'h00000002;                                     //1

	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd2 << 2) + (32'd3 << 13); //CD
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd3 << 2) + (32'd2 << 13); //CD
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd2 << 2) + (32'd7 << 13); //CH
	wdata = 32'h00000002;                                     //1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd7 << 2) + (32'd2 << 13); //CH
	wdata = 32'h00000002;                                     //1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd3 << 2) + (32'd4 << 13); //DE
	wdata = 32'h00000000;                                     //-1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd4 << 2) + (32'd3 << 13); //DE
	wdata = 32'h00000000;                                     //-1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd3 << 2) + (32'd7 << 13); //DH
	wdata = 32'h00000002;                                     //1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd7 << 2) + (32'd3 << 13); //DH
	wdata = 32'h00000002;                                     //1
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd4 << 2) + (32'd7 << 13); //EH
	wdata = 32'h00000002;                                     //1
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + (32'd7 << 2) + (32'd4 << 13); //EH
	wdata = 32'h00000002;                                     //1
	
	/////////////////////////////////////////////////////////////
	// Check weights
	
	@(posedge clk);
	wready = 1'b0;
	
	@(posedge clk);
	raddr = `WEIGHT_ADDR_BASE + (31'd0 << 2) + (31'd1 << 13);
	@(posedge clk);
	#1
	if(rdata[2:0] != 3'b000) $display("!!! AB FAILED !!!"); //A
	
	/////////////////////////////////////////////////////////////
	// Ach, Hans, run!
	
	@(posedge clk);
	wready = 1'b1;
	
	@(posedge clk);
	waddr = `START_ADDR;
	wdata = 32'h00000010;
	
	@(posedge clk);
	wready = 1'b0;

	#10000;
	
	@(posedge clk);
	wready = 1'b1;
	
	// Test resetting
	@(posedge clk);
	waddr = `START_ADDR;
	wdata = 32'h00000100;
	
	@(posedge clk);
	wready = 1'b0;

	#50000;
	
	/////////////////////////////////////////////////////////////
	// Read phases
	
	@(posedge clk);
	raddr = `PHASE_ADDR_BASE + (0 << 2);
	@(posedge clk);
	#1
	if(rdata < 32'h4) $display("!!! A FAILED !!!"); //A
	raddr = `PHASE_ADDR_BASE + (1 << 2);
	@(posedge clk);
	#1
	if(rdata > 32'h4) $display("!!! B FAILED !!!"); //B
	raddr = `PHASE_ADDR_BASE + (2 << 2);
	@(posedge clk);
	#1
	if(rdata < 32'h4) $display("!!! C FAILED !!!"); //C
	raddr = `PHASE_ADDR_BASE + (3 << 2);
	@(posedge clk);
	#1
	if(rdata < 32'h4) $display("!!! D FAILED !!!"); //D
	raddr = `PHASE_ADDR_BASE + (4 << 2);
	@(posedge clk);
	#1
	if(rdata > 32'h4) $display("!!! E FAILED !!!"); //E
	raddr = `PHASE_ADDR_BASE + (7 << 2);
	@(posedge clk);
	#1
	if(rdata < 32'h4) $display("!!! H FAILED !!!"); //F
        
        $display("If you got here with no fails, it passed!");	

	$finish();
    end
endmodule
