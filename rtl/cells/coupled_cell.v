

`timescale 1ns/1ps

`include "defines.vh"

module coupled_cell #(parameter N           = 8,
	              parameter INDEX       = 0,
	              parameter NUM_WEIGHTS = 15) (
		       // Oscillator RST
		       input  wire ising_rstn,

		       // Asynchronous Hopfield IO
	               input  wire [N-2:0] other_spins,
		       output wire my_spin,

		       // Synchronous AXI write interface
		       input  wire        clk,
		       input  wire        axi_rstn,
                       input  wire        wready,
		       input  wire        wr_addr_match,
		       input  wire [15:0] saddr,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );
    genvar i;

    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight [N-2:0];
    assign rdata = weight[saddr];

    generate for (i = 0; i < N; i = i + 1) begin: weight_loop
	if (i != INDEX) begin
	    localparam int_index = (i > INDEX) ? (i - 1) : i;
            wire [$clog2(NUM_WEIGHTS)-1:0] weight_nxt;
            assign weight_nxt = (wready & wr_addr_match & (i == saddr)) ?
	    	                 wdata[$clog2(NUM_WEIGHTS-1):0] :
    	                         weight[int_index]      ;
            always @(posedge clk) begin
                if (!axi_rstn) begin
              	    weight[int_index] <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
                end else begin
                    weight[int_index] <= weight_nxt;
                end
            end

	    wire [31:0] weight_probe;
	    assign weight_probe = weight[int_index];
        end
    end endgenerate

    // Local registers for storing initial spins
    reg spin;
    wire spin_nxt;
    assign spin_nxt = (wready & wr_addr_match & (INDEX == saddr)) ?
                       wdata[0] : spin;
    always @(posedge clk) begin
        if (!axi_rstn) begin
      	    spin <= 1'b0;
        end else begin
            spin <= spin_nxt;
        end
    end

    // Calculate the total input energy
    localparam ref_energy  = $floor(NUM_WEIGHTS * N / 2);
    localparam zero_energy = $floor(NUM_WEIGHTS / 2);
     
    generate for (i = 0; i < N-1; i = i + 1) begin: loop
        wire [$clog2(NUM_WEIGHTS * N)-1:0] energy;
	if (i == 0) begin
	    assign energy = other_spins[i] ? ref_energy + weight[i] - zero_energy :
		                             ref_energy - weight[i] + zero_energy ;
        end else begin
	    assign energy = other_spins[i] ? loop[i-1].energy + weight[i] - zero_energy :
		                             loop[i-1].energy - weight[i] + zero_energy ;
	end
    end endgenerate
    
    // Compare to local spin
    wire my_spin_int;
    assign my_spin_int = (loop[N-2].energy > ref_energy);

    `ifdef SIM
	reg my_spin_int_r;
	always @(my_spin_int) begin
	    #1
	    assign my_spin_int_r = my_spin_int;
	end
        assign my_spin = ising_rstn ? my_spin_int_r : spin;
    `else
        (* dont_touch = "yes" *) LDCE s_latch (.Q(my_spin), .D(my_spin_int), .G(ising_rstn), .GE(1'b1), .CLR(1'b0));
    `endif

endmodule
