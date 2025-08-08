`timescale 1ns / 1ps

//
// Module: synapse_memory_bram
// Description: A wrapper module for the Xilinx Single-Port BRAM.
//              This module is configured to act as a read-only synapse memory,
//              initialized from an external hex file.
//
module synapse_mem #(
    // --- Parameters for SNN Configuration ---
    parameter DATA_WIDTH = 8,      // Width of the synaptic weight data
    parameter ADDR_WIDTH = 14,     // Address width for the memory (supports up to 2^14 entries)
    parameter DEPTH      = 10000,  // Exact number of weights to store
    parameter INIT_FILE  = "weight_init.mem" // Name of the memory initialization file
)(
    // --- Simplified Ports for SNN Integration ---
    input  wire                      clk,          // System clock
    input  wire [ADDR_WIDTH-1:0]     i_rd_addr,    // Read address from the controller
    output wire signed [DATA_WIDTH-1:0] o_rd_data      // Weight data read from memory
);

    // --- Internal Instantiation of the Xilinx BRAM Template ---

    // Note: The template's port names (addra, clka, etc.) are used here.
    xilinx_single_port_ram_no_change #(
        .RAM_WIDTH(DATA_WIDTH),
        .RAM_DEPTH(DEPTH),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Use output register for better timing
        .INIT_FILE(INIT_FILE)
    ) u_bram_inst (
        .addra(i_rd_addr),      // Connect our read address to the BRAM's address port
        .clka(clk),             // Connect the system clock

        // --- Tie-off unused ports for read-only operation ---
        .dina({DATA_WIDTH{1'b0}}), // Tie write data to 0
        .wea(1'b0),             // Disable write enable
        .rsta(1'b0),            // Tie output register reset to inactive
        
        // --- Keep the RAM active ---
        .ena(1'b1),             // Always enable the RAM port
        .regcea(1'b1),          // Always enable the output register clock

        // --- Connect the output port ---
        .douta(o_rd_data)       // Connect BRAM's output to our module's output
    );

endmodule


//==============================================================================
// --- Xilinx BRAM Template (Provided by User) ---
// This is included here for completeness of the file.
//==============================================================================


//  Xilinx Single Port No Change RAM
//  This code implements a parameterizable single-port no-change memory where when data is written
//  to the memory, the output remains unchanged.  This is the most power efficient write mode.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

module xilinx_single_port_ram_no_change #(
  parameter RAM_WIDTH = 18,                       // Specify RAM data width
  parameter RAM_DEPTH = 1024,                     // Specify RAM depth (number of entries)
  parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // RAM input data
  input clka,                           // Clock
  input wea,                            // Write enable
  input ena,                            // RAM Enable, for additional power savings, disable port when not in use
  input rsta,                           // Output reset (does not affect memory contents)
  input regcea,                         // Output register enable
  output [RAM_WIDTH-1:0] douta          // RAM output data
);

  reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
  reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clka)
    if (ena)
      if (wea)
        BRAM[addra] <= dina;
      else
        ram_data <= BRAM[addra];

  //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
  generate
    if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register

      // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
       assign douta = ram_data;

    end else begin: output_register

      // The following is a 2 clock cycle read latency with improve clock-to-out timing

      reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};

      always @(posedge clka)
        if (rsta)
          douta_reg <= {RAM_WIDTH{1'b0}};
        else if (regcea)
          douta_reg <= ram_data;

      assign douta = douta_reg;

    end
  endgenerate

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule