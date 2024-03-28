

// Create an NxN array of coupled cells.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "coupled_cell.v"
`endif

module core_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5) (
		     input  wire ising_rstn,

		     output wire [N-1:0] outputs,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
                     input  wire [31:0] wr_addr,
                     input  wire [31:0] wdata,
		     input  wire [31:0] rd_addr,
		     output wire [31:0] rdata
	            );

    wire wr_match;
    assign wr_match = (wr_addr[31:24] == `WEIGHT_ADDR_MASK);

    // Split the address into S and D
    wire [15:0] s_addr;
    wire [15:0] d_addr;
    wire [15:0] sd_dist;
    wire [31:0] addr;

    assign addr = wready ? wr_addr : rd_addr;
    assign s_addr = {5'b0, addr[12: 2]} ;
    assign d_addr = {5'b0, addr[23:13]} ;

    // Create cells
    wire [N-1:0] spins;
    assign outputs = spins;

    genvar i;
    generate for (i = 0; i < N; i = i + 1) begin : column_loop
	wire [N-2:0] local_spins;
	if      (i == 0  ) begin assign local_spins = spins[N-1:1]; end
	else if (i == N-1) begin assign local_spins = spins[N-2:0]; end
	else               begin assign local_spins = {spins[N-1:i+1], spins[i-1:0]}; end

	wire sel_col = (d_addr == i);
	wire [31:0] rdata_cell;
        coupled_cell #(.N(N),
		       .INDEX(i),
	               .NUM_WEIGHTS(NUM_WEIGHTS))
	      i_cell  (.ising_rstn(ising_rstn),
		       .other_spins(local_spins),
		       .my_spin(spins[i]),

		       .clk(clk),
		       .axi_rstn(axi_rstn),
		       .wdata(wdata),
		       .wready(wready),
		       .wr_addr_match(sel_col),
		       .rdata(rdata_cell),
		       .saddr(s_addr));

	wire [31:0] rdata_out;
	if (i == 0) begin assign rdata_out = sel_col ? rdata_cell : 32'hAAAAAAAA; end
        else        begin assign rdata_out = sel_col ? rdata_cell : column_loop[i-1].rdata_out; end
    end endgenerate

    // Get read data
    assign rdata = column_loop[N-1].rdata_out;

endmodule
