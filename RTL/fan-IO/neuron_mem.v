`timescale 1ns / 1ps

//
// Module: neuron_mem_bram
// Description: A wrapper for the Xilinx Simple Dual Port BRAM, configured to
//              store neuron states (Vmem and refractory counter). It provides
//              a clean interface for the TDM controller.
//
module neuron_mem #(
    // --- SNN Configuration Parameters ---
    parameter NUM_NEURONS   = 10000,
    parameter ADDR_WIDTH    = 14,     // Address width for 10000 neurons (2^14 = 16384)
    parameter VMEM_WIDTH    = 16,     // Bit-width for membrane potential
    parameter REF_CTR_WIDTH = 4       // Bit-width for refractory counter
)(
    // --- Ports for TDM Controller ---
    input  wire                      clk,

    // --- Write Port (from PU output) ---
    input  wire                      i_wr_en,      // Write enable for this neuron's state
    input  wire [ADDR_WIDTH-1:0]     i_wr_addr,    // Address of the neuron to update
    input  wire signed [VMEM_WIDTH-1:0] i_vmem_in,    // New Vmem value to write
    input  wire [REF_CTR_WIDTH-1:0]  i_ref_ctr_in, // New refractory counter to write

    // --- Read Port (to PU input) ---
    input  wire [ADDR_WIDTH-1:0]     i_rd_addr,    // Address of the neuron to read
    output wire signed [VMEM_WIDTH-1:0] o_vmem_out,   // Vmem value read from memory
    output wire [REF_CTR_WIDTH-1:0]  o_ref_ctr_out // Refractory counter read from memory
);

    // --- Internal Data Packing Logic ---
    // We pack the 20-bit state (16-bit Vmem + 4-bit counter) into a 24-bit word (3 bytes).
    localparam NB_COL    = 3; // 3 bytes
    localparam COL_WIDTH = 8; // 8 bits per byte
    localparam RAM_WIDTH = NB_COL * COL_WIDTH; // Total width is 24 bits

    wire [RAM_WIDTH-1:0] packed_wr_data;
    wire [RAM_WIDTH-1:0] packed_rd_data;

    // Packing: Combine vmem and ref_ctr into a single 24-bit vector for writing.
    // Format: { 4'b0, ref_ctr[3:0], vmem[15:0] }
    assign packed_wr_data = { {(RAM_WIDTH - VMEM_WIDTH - REF_CTR_WIDTH){1'b0}}, i_ref_ctr_in, i_vmem_in };

    // Unpacking: Extract vmem and ref_ctr from the 24-bit vector read from memory.
    assign o_vmem_out    = packed_rd_data[VMEM_WIDTH-1:0];
    assign o_ref_ctr_out = packed_rd_data[VMEM_WIDTH + REF_CTR_WIDTH - 1 : VMEM_WIDTH];


    // --- Instantiate the Xilinx BRAM Template ---
    xilinx_simple_dual_port_byte_write_2_clock_ram #(
        .NB_COL(NB_COL),
        .COL_WIDTH(COL_WIDTH),
        .RAM_DEPTH(NUM_NEURONS),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Ensures 2-clock latency for better timing
        .INIT_FILE("")                        // Neuron states are initialized to 0, not from a file
    ) u_bram_inst (
        // Write Port (Port A)
        .addra(i_wr_addr),
        .dina(packed_wr_data),
        .clka(clk),
        // Convert single write enable to byte-write enable (write all bytes at once)
        .wea({NB_COL{i_wr_en}}),

        // Read Port (Port B)
        .addrb(i_rd_addr),
        .clkb(clk),             // Use the same clock for reading and writing
        .enb(1'b1),             // Always enable the read port
        .rstb(1'b0),            // Tie output register reset to inactive
        .regceb(1'b1),          // Always enable the output register clock
        .doutb(packed_rd_data)
    );

endmodule


//==============================================================================
// --- Xilinx BRAM Template (Provided by User) ---
//==============================================================================

module xilinx_simple_dual_port_byte_write_2_clock_ram #(
    parameter NB_COL          = 8,
    parameter COL_WIDTH       = 8,
    parameter RAM_DEPTH       = 512,
    parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE",
    parameter INIT_FILE       = ""
) (
    input [clogb2(RAM_DEPTH)-1:0] addra,
    input [clogb2(RAM_DEPTH)-1:0] addrb,
    input [(NB_COL*COL_WIDTH)-1:0] dina,
    input clka,
    input clkb,
    input [NB_COL-1:0] wea,
    input enb,
    input rstb,
    input regceb,
    output [(NB_COL*COL_WIDTH)-1:0] doutb
);

    reg [(NB_COL*COL_WIDTH)-1:0] BRAM [RAM_DEPTH-1:0];
    reg [(NB_COL*COL_WIDTH)-1:0] ram_data = {(NB_COL*COL_WIDTH){1'b0}};

    generate
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
                    BRAM[ram_index] = {(NB_COL*COL_WIDTH){1'b0}};
        end
    endgenerate

    always @(posedge clkb)
        if (enb)
            ram_data <= BRAM[addrb];

    generate
    genvar i;
        for (i = 0; i < NB_COL; i = i+1) begin: byte_write
            always @(posedge clka)
                if (wea[i])
                    BRAM[addra][(i+1)*COL_WIDTH-1:i*COL_WIDTH] <= dina[(i+1)*COL_WIDTH-1:i*COL_WIDTH];
        end
    endgenerate

    generate
        if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register
            assign doutb = ram_data;
        end else begin: output_register
            reg [(NB_COL*COL_WIDTH)-1:0] doutb_reg = {(NB_COL*COL_WIDTH){1'b0}};
            always @(posedge clkb)
                if (rstb)
                    doutb_reg <= {(NB_COL*COL_WIDTH){1'b0}};
                else if (regceb)
                    doutb_reg <= ram_data;
            assign doutb = doutb_reg;
        end
    endgenerate

    function integer clogb2;
      input integer depth;
      begin
        for (clogb2=0; (1<<clogb2) < depth; clogb2=clogb2+1)
          ;
      end
    endfunction

endmodule
