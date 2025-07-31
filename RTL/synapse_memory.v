`timescale 1ns / 1ps

// Module: synapse_memory
// Description:
//   An ideal memory module for the current design phase.
//   It's synthesizable as a BRAM, ensuring performance, and uses
//   `$readmemh` for easy testing, aligning with the project goals.
module synapse_memory #(
    parameter DATA_WIDTH  = 8,
    parameter DEPTH       = 10000,
    parameter ADDR_WIDTH  = 14
)(
    input   wire                        clk,
    input   wire                        rst_n,

    // Read Port
    input   wire [ADDR_WIDTH-1:0]       i_read_addr,
    output  reg  [DATA_WIDTH-1:0]       o_read_weight,

    // Write Port (for future extensibility, e.g., SPI/UART loading)
    input   wire                        i_write_en,
    input   wire [ADDR_WIDTH-1:0]       i_write_addr,
    input   wire [DATA_WIDTH-1:0]       i_write_data
);

    // Directive to enforce BRAM implementation in synthesis
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialize memory only during simulation
    `ifndef SYNTHESIS
    initial begin
        // For simulation, pre-load weights from a file.
        // For synthesis, this block is ignored, and the BRAM
        // will be initialized with the data from the .mem file
        // as part of the bitstream.
        $readmemh("weight_init.hex", mem);
    end
    `endif

    // Synchronous read and write logic
    always @(posedge clk) begin
        // Read operation
        o_read_weight <= mem[i_read_addr];

        // Write operation
        if (i_write_en) begin
            mem[i_write_addr] <= i_write_data;
        end
    end

endmodule
