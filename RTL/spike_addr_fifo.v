`timescale 1ns / 1ps

// --- Behavioral Model for a Simple FIFO ---
module spike_addr_fifo #(
    parameter DATA_WIDTH = 14,
    parameter DEPTH      = 128
)(
    input wire clk, rst_n,
    input wire i_wr_en,
    input wire [DATA_WIDTH-1:0] i_wdata,
    input wire i_rd_en,
    output wire [DATA_WIDTH-1:0] o_rdata,
    output wire o_valid
);
    // This is a simplified, non-synthesizable model for simulation.
    // A real implementation would use a proper FIFO structure.
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr, rd_ptr;
    reg [$clog2(DEPTH)+1:0] count;

    assign o_rdata = mem[rd_ptr];
    assign o_valid = (count > 0);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= 0; rd_ptr <= 0; count <= 0;
        end else begin
            if (i_wr_en && !i_rd_en) begin
                mem[wr_ptr] <= i_wdata;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end else if (!i_wr_en && i_rd_en && o_valid) begin
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end else if (i_wr_en && i_rd_en && o_valid) begin
                mem[wr_ptr] <= i_wdata;
                wr_ptr <= wr_ptr + 1;
                rd_ptr <= rd_ptr + 1;
            end
        end
    end
endmodule