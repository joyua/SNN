`timescale 1ns / 1ps

//
// Module: source_controller
// Description: A controller for a fan-in (source) neuron system. It orchestrates
//              the process of collecting spikes, performing a MAC operation, and
//              updating the neuron's state using a TDM-ready PU and memories.
//
module source_controller #(
    // --- Parameters ---
    parameter ADDR_WIDTH    = 14,
    parameter VMEM_WIDTH    = 16,
    parameter REF_CTR_WIDTH = 4,
    parameter DATA_WIDTH    = 8,
    parameter SUM_WIDTH     = 16,
    parameter SOURCE_NEURON_ADDR = 0 // This system controls a single neuron at address 0
)(
    // --- Global Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Control ---
    input  wire                      i_start_processing,
    output reg                       o_processing_done,

    // --- Input Spike FIFO Interface ---
    output reg                       o_spike_fifo_rden,
    input  wire [ADDR_WIDTH-1:0]     i_spike_fifo_rdata,
    input  wire                      i_spike_fifo_empty,

    // --- Synapse Memory Interface ---
    output reg  [ADDR_WIDTH-1:0]     o_synapse_mem_addr,
    input  wire signed [DATA_WIDTH-1:0] i_weight_from_mem,

    // --- MAC Unit Interface ---
    output reg                       o_mac_clear,
    output reg                       o_mac_accumulate,
    input  wire signed [SUM_WIDTH-1:0]  i_mac_sum_out,

    // --- Neuron State Memory Interface ---
    output reg  [ADDR_WIDTH-1:0]     o_neuron_mem_rd_addr,
    output reg  [ADDR_WIDTH-1:0]     o_neuron_mem_wr_addr,
    output reg                       o_neuron_mem_wr_en,
    input  wire signed [VMEM_WIDTH-1:0] i_vmem_from_mem,
    input  wire [REF_CTR_WIDTH-1:0]  i_ref_ctr_from_mem,

    // --- Neuron PU Interface ---
    output reg                       o_pu_in_valid,
    input  wire signed [VMEM_WIDTH-1:0] i_pu_vmem_out,
    input  wire [REF_CTR_WIDTH-1:0]  i_pu_ref_ctr_out,
    output reg signed [VMEM_WIDTH-1:0] o_pu_vmem_in,
    output reg [REF_CTR_WIDTH-1:0]  o_pu_ref_ctr_in,
    output reg signed [SUM_WIDTH-1:0]  o_pu_syn_current_in
);

    // --- FSM State Definition ---
    localparam S_IDLE           = 3'b000;
    localparam S_MAC_CLEAR      = 3'b001;
    localparam S_MAC_RUN        = 3'b010;
    localparam S_NEURON_FETCH   = 3'b011;
    localparam S_NEURON_UPDATE  = 3'b100;
    localparam S_NEURON_WRITEBACK = 3'b101;
    localparam S_DONE           = 3'b110;

    reg [2:0] current_state, next_state;
    
    // Pipeline registers to handle memory latencies
    reg weight_valid_pipe1, weight_valid_pipe2;
    reg signed [VMEM_WIDTH-1:0] vmem_pipe1, vmem_pipe2;
    reg [REF_CTR_WIDTH-1:0]  ref_ctr_pipe1, ref_ctr_pipe2;

    // --- FSM Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S_IDLE;
        else        current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE:           if (i_start_processing) next_state = S_MAC_CLEAR;
            S_MAC_CLEAR:      next_state = S_MAC_RUN;
            S_MAC_RUN:        if (i_spike_fifo_empty) next_state = S_NEURON_FETCH;
            S_NEURON_FETCH:   next_state = S_NEURON_UPDATE;
            S_NEURON_UPDATE:  next_state = S_NEURON_WRITEBACK;
            S_NEURON_WRITEBACK: next_state = S_DONE;
            S_DONE:           next_state = S_IDLE;
        endcase
    end

    // --- Main Control and Datapath Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs
            o_processing_done <= 1'b0; o_spike_fifo_rden <= 1'b0;
            o_synapse_mem_addr <= 0; o_mac_clear <= 1'b0;
            o_mac_accumulate <= 1'b0; o_neuron_mem_rd_addr <= 0;
            o_neuron_mem_wr_addr <= 0; o_neuron_mem_wr_en <= 1'b0;
            o_pu_in_valid <= 1'b0;
            weight_valid_pipe1 <= 0; weight_valid_pipe2 <= 0;
        end else begin
            // Default assignments
            o_processing_done <= 1'b0; o_spike_fifo_rden <= 1'b0;
            o_mac_clear <= 1'b0; o_mac_accumulate <= 1'b0;
            o_neuron_mem_wr_en <= 1'b0; o_pu_in_valid <= 1'b0;

            // Pipeline for synapse memory read (2-cycle latency)
            weight_valid_pipe1 <= o_spike_fifo_rden;
            weight_valid_pipe2 <= weight_valid_pipe1;
            
            // Pipeline for neuron state memory read (2-cycle latency)
            vmem_pipe1 <= i_vmem_from_mem; ref_ctr_pipe1 <= i_ref_ctr_from_mem;
            vmem_pipe2 <= vmem_pipe1;      ref_ctr_pipe2 <= ref_ctr_pipe1;

            case (current_state)
                S_MAC_CLEAR: begin
                    o_mac_clear <= 1'b1;
                end
                S_MAC_RUN: begin
                    // Read from FIFO, which drives the synapse memory address
                    o_spike_fifo_rden <= !i_spike_fifo_empty;
                    o_synapse_mem_addr <= i_spike_fifo_rdata;
                    // After 2 cycles, the weight is ready. Tell MAC to accumulate.
                    if (weight_valid_pipe2) begin
                        o_mac_accumulate <= 1'b1;
                    end
                end
                S_NEURON_FETCH: begin
                    // MAC phase is done. Read this neuron's state from memory.
                    o_neuron_mem_rd_addr <= SOURCE_NEURON_ADDR;
                end
                S_NEURON_UPDATE: begin
                    // State data has arrived after 2 cycles. Send all data to PU.
                    o_pu_in_valid <= 1'b1;
                    o_pu_vmem_in <= vmem_pipe2;
                    o_pu_ref_ctr_in <= ref_ctr_pipe2;
                    o_pu_syn_current_in <= i_mac_sum_out;
                end
                S_NEURON_WRITEBACK: begin
                    // PU result is ready after 1 cycle. Write it back to memory.
                    o_neuron_mem_wr_en <= 1'b1;
                    o_neuron_mem_wr_addr <= SOURCE_NEURON_ADDR;
                end
                S_DONE: begin
                    o_processing_done <= 1'b1;
                end
            endcase
        end
    end

endmodule
