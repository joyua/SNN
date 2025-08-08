`timescale 1ns / 1ps

//
// Module: snn_top
// Description: Top-level module integrating all SNN components for synthesis
//              Supports 1:10,000 fan-in structure with single neuron processing
//
module source_top #(
    // === Global Parameters ===
    parameter NUM_INPUTS        = 10000,        // Total spike inputs
    parameter ADDR_WIDTH        = 14,           // log2(10000) 
    parameter DATA_WIDTH        = 8,            // Weight data width
    parameter VMEM_WIDTH        = 16,           // Membrane potential width
    parameter REF_CTR_WIDTH     = 4,            // Refractory counter width
    parameter SUM_WIDTH         = 16,           // MAC sum width
    parameter FIFO_DEPTH        = 256,          // Spike address FIFO depth
    parameter SOURCE_NEURON_ADDR = 0            // Single neuron address
)(
    // === Global Ports ===
    input  wire                      clk,
    input  wire                      rst_n,
    
    // === External Interface ===
    input  wire                      i_start_processing,     // Start new processing cycle
    
    // === Serial Spike Input Interface ===
    input  wire                      i_spike_data_valid,     // Valid spike data
    input  wire [ADDR_WIDTH-1:0]     i_spike_addr,           // Spike address (serial)
    input  wire                      i_spike_data_last,      // Last spike in current frame
    
    // === AXI4-Stream like interface for spikes ===
    input  wire                      i_spike_tvalid,         // Valid spike
    output wire                      i_spike_tready,         // Ready for spike
    input  wire [ADDR_WIDTH-1:0]     i_spike_tdata,          // Spike address
    input  wire                      i_spike_tlast,          // End of spike frame
    
    // === Outputs ===
    output wire                      o_processing_done,      // Processing complete signal
    output wire                      o_spike_output,         // Final neuron spike output
    
    // === Status/Debug Outputs ===
    output wire                      o_fifo_full,            // FIFO overflow indicator
    output wire                      o_fifo_empty,           // FIFO empty status
    output wire [7:0]                o_num_spikes_detected   // Number of active spikes
);

    // ========================================================================
    // === Internal Signal Declarations ===
    // ========================================================================
    
    // --- Input Interface Control ---
    reg  input_complete;
    wire input_tready_int;
    
    // --- FIFO Signals ---
    wire                    fifo_wr_en;
    wire                    fifo_rd_en;
    wire [ADDR_WIDTH-1:0]   fifo_rd_data;
    wire                    fifo_empty_int;
    wire                    fifo_full_int;
    wire [7:0]              fifo_count;
    
    // --- Controller Signals ---
    wire                    controller_done;
    
    // --- Synapse Memory Signals ---
    wire [ADDR_WIDTH-1:0]   synapse_mem_addr;
    wire signed [DATA_WIDTH-1:0] weight_from_mem;
    
    // --- Neuron Memory Signals ---
    wire [ADDR_WIDTH-1:0]   neuron_mem_rd_addr;
    wire [ADDR_WIDTH-1:0]   neuron_mem_wr_addr;
    wire                    neuron_mem_wr_en;
    wire signed [VMEM_WIDTH-1:0] vmem_from_mem;
    wire [REF_CTR_WIDTH-1:0] ref_ctr_from_mem;
    
    // --- MAC Signals ---
    wire                    mac_clear;
    wire                    mac_accumulate;
    wire signed [SUM_WIDTH-1:0] mac_sum_out;
    
    // --- Neuron PU Signals ---
    wire                    pu_in_valid;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_in;
    wire [REF_CTR_WIDTH-1:0] pu_ref_ctr_in;
    wire signed [SUM_WIDTH-1:0] pu_syn_current_in;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_out;
    wire [REF_CTR_WIDTH-1:0] pu_ref_ctr_out;
    wire                    pu_spike_out;
    
    // --- Control Logic ---
    reg start_processing_reg;
    reg [7:0] spike_counter;
    
    // ========================================================================
    // === Input Interface Logic ===
    // ========================================================================
    
    // Ready signal - can accept data when FIFO is not full
    assign i_spike_tready = !fifo_full_int;
    assign input_tready_int = i_spike_tready;
    
    // Input complete detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_complete <= 1'b0;
        end else if (i_start_processing) begin
            input_complete <= 1'b0;  // Reset at start
        end else if (i_spike_tvalid && i_spike_tready && i_spike_tlast) begin
            input_complete <= 1'b1;  // Set when last spike received
        end else if (controller_done) begin
            input_complete <= 1'b0;  // Reset when processing done
        end
    end
    
    // ========================================================================
    // === Spike Counter for Debug ===
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_counter <= 8'b0;
        end else if (i_start_processing) begin
            spike_counter <= 8'b0;  // Reset counter at start
        end else if (i_spike_tvalid && i_spike_tready) begin
            spike_counter <= spike_counter + 1'b1;
        end
    end
    
    assign o_num_spikes_detected = spike_counter;
    
    // ========================================================================
    // === FIFO Interface Logic ===
    // ========================================================================
    assign fifo_wr_en = i_spike_tvalid && i_spike_tready;
    assign o_fifo_full = fifo_full_int;
    assign o_fifo_empty = fifo_empty_int;
    
    // ========================================================================
    // === Output Assignments ===
    // ========================================================================
    assign o_processing_done = controller_done;
    assign o_spike_output = pu_spike_out;
    
    // ========================================================================
    // === Module Instantiations ===
    // ========================================================================
    
    // --- 1. Spike Address FIFO ---
    // Direct connection from AXI4-Stream interface to FIFO
    spike_fifo #(
        .DATA_WIDTH(ADDR_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) u_spike_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .i_wr_en(fifo_wr_en),
        .i_wr_data(i_spike_tdata),          // Direct from input
        .i_rd_en(fifo_rd_en),
        .o_rd_data(fifo_rd_data),
        .o_empty(fifo_empty_int),
        .o_full(fifo_full_int),
        .o_count(fifo_count)
    );
    
    // --- 2. Source Controller ---
    source_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .VMEM_WIDTH(VMEM_WIDTH),
        .REF_CTR_WIDTH(REF_CTR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SUM_WIDTH(SUM_WIDTH),
        .SOURCE_NEURON_ADDR(SOURCE_NEURON_ADDR)
    ) u_source_controller (
        .clk(clk),
        .rst_n(rst_n),
        .i_start_processing(input_complete),    // Start after all spikes received
        .o_processing_done(controller_done),
        
        // FIFO Interface
        .o_spike_fifo_rden(fifo_rd_en),
        .i_spike_fifo_rdata(fifo_rd_data),
        .i_spike_fifo_empty(fifo_empty_int),
        
        // Synapse Memory Interface
        .o_synapse_mem_addr(synapse_mem_addr),
        .i_weight_from_mem(weight_from_mem),
        
        // MAC Interface
        .o_mac_clear(mac_clear),
        .o_mac_accumulate(mac_accumulate),
        .i_mac_sum_out(mac_sum_out),
        
        // Neuron Memory Interface
        .o_neuron_mem_rd_addr(neuron_mem_rd_addr),
        .o_neuron_mem_wr_addr(neuron_mem_wr_addr),
        .o_neuron_mem_wr_en(neuron_mem_wr_en),
        .i_vmem_from_mem(vmem_from_mem),
        .i_ref_ctr_from_mem(ref_ctr_from_mem),
        
        // Neuron PU Interface
        .o_pu_in_valid(pu_in_valid),
        .i_pu_vmem_out(pu_vmem_out),
        .i_pu_ref_ctr_out(pu_ref_ctr_out),
        .o_pu_vmem_in(pu_vmem_in),
        .o_pu_ref_ctr_in(pu_ref_ctr_in),
        .o_pu_syn_current_in(pu_syn_current_in)
    );
    
    // --- 3. Synapse Memory ---
    synapse_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(NUM_INPUTS),
        .INIT_FILE("weight_init.mem")
    ) u_synapse_mem (
        .clk(clk),
        .i_rd_addr(synapse_mem_addr),
        .o_rd_data(weight_from_mem)
    );
    
    // --- 4. Neuron State Memory ---
    neuron_lutram #(
        .NUM_NEURONS(1),                    // Single neuron for now
        .VMEM_WIDTH(VMEM_WIDTH),
        .REF_CTR_WIDTH(REF_CTR_WIDTH)
    ) u_neuron_lutram (
        .clk(clk),
        .rst_n(rst_n),
        
        // Write Port (from Controller/PU)
        .i_wr_en(neuron_mem_wr_en),
        .i_wr_addr(neuron_mem_wr_addr[0:0]),  // Only bit [0] for single neuron
        .i_vmem_in(pu_vmem_out),
        .i_ref_ctr_in(pu_ref_ctr_out),
        
        // Read Port (to Controller)
        .i_rd_addr(neuron_mem_rd_addr[0:0]),  // Only bit [0] for single neuron
        .o_vmem_out(vmem_from_mem),
        .o_ref_ctr_out(ref_ctr_from_mem)
    );
    
    // --- 5. MAC Unit ---
    mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .SUM_WIDTH(SUM_WIDTH)
    ) u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .i_clear(mac_clear),
        .i_accumulate(mac_accumulate),
        .i_syn_weight(weight_from_mem),
        .o_sum(mac_sum_out)
    );
    
    // --- 6. Neuron Processing Unit ---
    neuron_pu #(
        .VMEM_WIDTH(VMEM_WIDTH),
        .DATA_WIDTH(SUM_WIDTH),              // Use SUM_WIDTH for synaptic current
        .V_THRESH(120),
        .V_RESET(0),
        .LEAK_VAL(2),
        .REFRACTORY_PERIOD(5)
    ) u_neuron_pu (
        .clk(clk),
        .rst_n(rst_n),
        .i_in_valid(pu_in_valid),
        .i_vmem_in(pu_vmem_in),
        .i_ref_ctr_in(pu_ref_ctr_in),
        .i_syn_current(pu_syn_current_in),
        .o_spike(pu_spike_out),
        .o_vmem_out(pu_vmem_out),
        .o_ref_ctr_out(pu_ref_ctr_out)
    );

endmodule

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