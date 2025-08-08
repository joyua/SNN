`timescale 1ns / 1ps

//
// Module: target_neuron_system
// Description: The top-level module for the target neuron layer. It integrates the
//              TDM controller, neuron PU, synapse memory, and neuron state memory
//              to process 10,000 neurons sequentially based on a single source spike.
//
module target_neuron_system #(
    // --- Global SNN Configuration Parameters ---
    parameter NUM_NEURONS   = 10000,
    parameter ADDR_WIDTH    = 14,
    parameter VMEM_WIDTH    = 16,
    parameter REF_CTR_WIDTH = 4,
    parameter DATA_WIDTH    = 8
)(
    // --- System-Level Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Input from the Source Neuron ---
    input  wire                      i_source_spike,   // Trigger to start the update loop

    // --- Outputs to the external Spike FIFO ---
    output wire                      o_spike_fifo_wr_en,   // Write enable for the spike FIFO
    output wire [ADDR_WIDTH-1:0]     o_spike_fifo_wr_addr, // Address of the neuron that spiked

    // --- Status Output ---
    output wire                      o_processing_done // Signals when the 10,000-neuron loop is complete
);

    //================================================================
    // --- Internal Wires for Inter-Module Connections ---
    //================================================================

    // Controller -> Neuron Memory
    wire [ADDR_WIDTH-1:0]     neuron_mem_rd_addr;
    wire [ADDR_WIDTH-1:0]     neuron_mem_wr_addr;
    wire                       neuron_mem_wr_en;

    // Neuron Memory -> Controller
    wire signed [VMEM_WIDTH-1:0] vmem_from_mem;
    wire [REF_CTR_WIDTH-1:0]  ref_ctr_from_mem;

    // Controller -> Synapse Memory
    wire [ADDR_WIDTH-1:0]     synapse_mem_rd_addr;

    // Synapse Memory -> Controller
    wire signed [DATA_WIDTH-1:0] weight_from_mem;

    // Controller -> PU
    wire                       pu_in_valid;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_in;
    wire [REF_CTR_WIDTH-1:0]  pu_ref_ctr_in;
    wire signed [DATA_WIDTH-1:0] pu_syn_current_in;

    // PU -> Controller
    wire                       pu_spike_out;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_out;
    wire [REF_CTR_WIDTH-1:0]  pu_ref_ctr_out;

    //================================================================
    // --- Module Instantiations ---
    //================================================================

    // 1. TDM Controller (The Brain)
    tdm_controller #(
        .NUM_NEURONS(NUM_NEURONS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .VMEM_WIDTH(VMEM_WIDTH),
        .REF_CTR_WIDTH(REF_CTR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .i_source_spike(i_source_spike),
        .o_processing_done(o_processing_done),
        .o_neuron_mem_rd_addr(neuron_mem_rd_addr),
        .o_neuron_mem_wr_addr(neuron_mem_wr_addr),
        .o_neuron_mem_wr_en(neuron_mem_wr_en),
        .i_vmem_from_mem(vmem_from_mem),
        .i_ref_ctr_from_mem(ref_ctr_from_mem),
        .o_neuron_mem_vmem_in(pu_vmem_out), // PU output is routed to memory write input
        .o_neuron_mem_ref_ctr_in(pu_ref_ctr_out),
        .o_synapse_mem_rd_addr(synapse_mem_rd_addr),
        .i_weight_from_mem(weight_from_mem),
        .o_pu_in_valid(pu_in_valid),
        .i_pu_spike_out(pu_spike_out),
        .i_pu_vmem_out(pu_vmem_out),
        .i_pu_ref_ctr_out(pu_ref_ctr_out),
        .o_pu_vmem_in(pu_vmem_in),
        .o_pu_ref_ctr_in(pu_ref_ctr_in),
        .o_pu_syn_current_in(pu_syn_current_in),
        .o_spike_fifo_wr_en(o_spike_fifo_wr_en),
        .o_spike_fifo_wr_addr(o_spike_fifo_wr_addr)
    );

    // 2. Synapse Memory (Weight Storage)
    synapse_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(NUM_NEURONS),
        .INIT_FILE("weight_init.mem")
    ) u_synapse_mem (
        .clk(clk),
        .i_rd_addr(synapse_mem_rd_addr),
        .o_rd_data(weight_from_mem)
    );

    // 3. Neuron State Memory (Vmem & Ref_ctr Storage)
    neuron_mem #(
        .NUM_NEURONS(NUM_NEURONS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .VMEM_WIDTH(VMEM_WIDTH),
        .REF_CTR_WIDTH(REF_CTR_WIDTH)
    ) u_neuron_mem (
        .clk(clk),
        .i_wr_en(neuron_mem_wr_en),
        .i_wr_addr(neuron_mem_wr_addr),
        .i_vmem_in(pu_vmem_out), // PU output is the data to be written
        .i_ref_ctr_in(pu_ref_ctr_out),
        .i_rd_addr(neuron_mem_rd_addr),
        .o_vmem_out(vmem_from_mem),
        .o_ref_ctr_out(ref_ctr_from_mem)
    );

    // 4. Neuron Processing Unit (The Worker)
    neuron_pu #(
        .VMEM_WIDTH(VMEM_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .REFRACTORY_PERIOD(5) // Example value
    ) u_pu (
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
