`timescale 1ns / 1ps

//==============================================================================
// === FIFO Module ===
//==============================================================================

module spike_fifo #(
    parameter DATA_WIDTH = 14,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Write Interface
    input  wire                     i_wr_en,
    input  wire [DATA_WIDTH-1:0]    i_wr_data,
    
    // Read Interface  
    input  wire                     i_rd_en,
    output wire [DATA_WIDTH-1:0]    o_rd_data,
    
    // Status
    output wire                     o_empty,
    output wire                     o_full,
    output wire [7:0]               o_count
);

    // Internal memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Pointers
    reg [ADDR_WIDTH:0] wr_ptr;  // Extra bit for full/empty detection
    reg [ADDR_WIDTH:0] rd_ptr;  // Extra bit for full/empty detection
    
    // Status signals
    wire wrap_around = wr_ptr[ADDR_WIDTH] ^ rd_ptr[ADDR_WIDTH];
    assign o_empty = (wr_ptr == rd_ptr);
    assign o_full = wrap_around && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    
    // Count calculation
    assign o_count = o_empty ? 8'b0 : 
                    (wr_ptr >= rd_ptr) ? (wr_ptr - rd_ptr) : 
                    (DEPTH - rd_ptr + wr_ptr);
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (i_wr_en && !o_full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= i_wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (i_rd_en && !o_empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
    
    // Output data
    assign o_rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

endmodule