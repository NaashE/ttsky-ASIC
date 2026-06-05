`default_nettype none

// ============================================================
// Module: voxel_ram
//   Single-bit occupancy RAM.  32^3 = 32768 bits = 4096 bytes.
//   ADDR_BITS=15: depth = 2^15 = 32768 bit locations.
//   The `initial` zero-fill is SIM-only (guarded with `ifdef SIM).
//   On real hardware, scene is loaded via VOXEL_WRITE_BLOCK which
//   zero-clears before writing (CMD 0x10 VOXEL_CLEAR).
// ============================================================
module voxel_ram #(
    parameter int  ADDR_BITS   = 15,
    parameter bit  SYNC_READ   = 1'b1,
    parameter bit  WRITE_FIRST = 1'b1
)(
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [ADDR_BITS-1:0]  raddr,
    output logic                  rdata,

    input  logic                  we,
    input  logic [ADDR_BITS-1:0]  waddr,
    input  logic                  wdata
);

    localparam int DEPTH = 1 << ADDR_BITS;
    logic mem [0:DEPTH-1];

`ifdef SIM
    // SIM-only: initialise all bits to 0 so unloaded voxels are transparent.
    integer _ii;
    initial begin
        for (_ii = 0; _ii < DEPTH; _ii = _ii + 1)
            mem[_ii] = 1'b0;
    end
`endif

    // Write (sync)
    always_ff @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end

    generate
        if (SYNC_READ) begin : g_sync_read
            logic [ADDR_BITS-1:0] raddr_q;
            logic we_q;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    raddr_q <= '0;
                    we_q    <= 1'b0;
                end else begin
                    raddr_q <= raddr;
                    we_q    <= we;
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    rdata <= 1'b0;
                end else begin
                    if (WRITE_FIRST && we && (waddr == raddr_q))
                        rdata <= wdata;
                    else
                        rdata <= mem[raddr_q];
                end
            end
        end else begin : g_comb_read
            always_comb rdata = mem[raddr];
        end
    endgenerate

endmodule

`default_nettype wire
