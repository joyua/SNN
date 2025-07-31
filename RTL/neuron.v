`timescale 1ns / 1ps

//
// Module: neuron
// Author: Gemini & User
// Version: 1.0
// Description:
//   The top-level module for the single-core SNN processor.
//   It instantiates and connects all sub-modules to form a complete,
//   functional time-multiplexed SNN core.
//

module neuron #(
    // --- Global System Parameters ---
    parameter DATA_WIDTH      = 8,
    parameter FSM_WIDTH       = 2,
    parameter NEURON_COUNT    = 10000,
    parameter ADDR_WIDTH      = 14,
    parameter WEIGHT_WIDTH    = 8,
    parameter SUM_WIDTH       = 16,
    parameter STATE_VEC_WIDTH = DATA_WIDTH*2 + FSM_WIDTH
)(
    // --- Top-level I/O ---
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        i_global_start,

    // --- Input Spike Event Interface ---
    input   wire [ADDR_WIDTH-1:0]       i_spike_event_addr,
    input   wire                        i_spike_event_valid,

    // --- Output Spike Event Interface ---
    output  wire                        o_spike_out_valid,
    output  wire [ADDR_WIDTH-1:0]       o_spike_out_addr,

    // --- Status Port ---
    output  wire                        o_snn_done
);

    // --- Internal Wires for Inter-module Connection ---
    // main_ctrl <-> neuron_state_memory
    wire [ADDR_WIDTH-1:0]       state_mem_addr_w;
    wire                        state_mem_wr_en_w;
    wire [STATE_VEC_WIDTH-1:0]  state_mem_wdata_w;
    wire [STATE_VEC_WIDTH-1:0]  state_mem_rdata_w;

    // main_ctrl <-> synapse_mem_ctrl
    wire                        syn_fetch_start_w;
    wire                        syn_fetch_done_w;
    wire [WEIGHT_WIDTH-1:0]     syn_weight_data_w;
    wire                        syn_weight_valid_w;

    // synapse_mem_ctrl <-> synapse_memory
    wire [ADDR_WIDTH-1:0]       syn_mem_addr_w;
    wire [WEIGHT_WIDTH-1:0]     syn_mem_rdata_w;

    // synapse_mem_ctrl <-> spike_addr_fifo
    wire [ADDR_WIDTH-1:0]       fifo_rdata_w;
    wire                        fifo_valid_w;
    wire                        fifo_rden_w;

    // main_ctrl <-> mac_unit
    wire                        mac_clear_w;
    wire                        mac_accumulate_w;
    wire [SUM_WIDTH-1:0]        mac_sum_w;

    // main_ctrl <-> neuron_body
    wire                        neuron_body_start_w;
    wire [DATA_WIDTH-1:0]       neuron_body_mac_sum_w;
    wire [STATE_VEC_WIDTH-1:0]  neuron_body_state_in_w;
    wire [STATE_VEC_WIDTH-1:0]  neuron_body_state_out_w;
    wire                        neuron_body_spike_w;


    //================================================================
    // --- Module Instantiation ---
    //================================================================

    // 1. Main Controller - The Brain
    main_ctrl #(
        .DATA_WIDTH(DATA_WIDTH), .FSM_WIDTH(FSM_WIDTH), .NEURON_COUNT(NEURON_COUNT),
        .ADDR_WIDTH(ADDR_WIDTH), .STATE_VEC_WIDTH(STATE_VEC_WIDTH)
    ) u_main_ctrl (
        .clk(clk), .rst_n(rst_n), .i_global_start(i_global_start),
        .o_neuron_state_addr(state_mem_addr_w),
        .o_neuron_state_wr_en(state_mem_wr_en_w),
        .o_neuron_state_wdata(neuron_body_state_out_w), // Connects neuron_body output to memory input
        .i_neuron_state_rdata(state_mem_rdata_w),
        .o_syn_fetch_start(syn_fetch_start_w),
        .i_syn_fetch_done(syn_fetch_done_w),
        .i_syn_weight_data(syn_weight_data_w),
        .i_syn_weight_valid(syn_weight_valid_w),
        .o_mac_clear(mac_clear_w),
        .o_mac_accumulate(mac_accumulate_w),
        .i_mac_sum(mac_sum_w),
        .o_neuron_body_start(neuron_body_start_w),
        .o_neuron_body_mac_sum(mac_sum_w),
        .o_neuron_body_state_in(state_mem_rdata_w), // Connects memory output to neuron_body input
        .i_neuron_body_state_out(neuron_body_state_out_w),
        .i_neuron_body_spike(neuron_body_spike_w),
        .o_spike_out_valid(o_spike_out_valid),
        .o_spike_out_addr(o_spike_out_addr),
        .o_snn_done(o_snn_done)
    );

    // 2. Neuron State Memory - The Neuron Register File
    neuron_state_memory #(
        .NEURON_COUNT(NEURON_COUNT), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .FSM_WIDTH(FSM_WIDTH)
    ) u_neuron_state_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(state_mem_addr_w),
        .o_read_data(state_mem_rdata_w),
        .i_write_en(state_mem_wr_en_w),
        .i_write_addr(state_mem_addr_w), // Assuming same address for read-modify-write
        .i_write_data(neuron_body_state_out_w)
    );

    // 3. Synapse Memory - The Weight Database
    synapse_memory #(
        .DATA_WIDTH(WEIGHT_WIDTH), .DEPTH(NEURON_COUNT*1), .ADDR_WIDTH(ADDR_WIDTH) // DEPTH can be larger
    ) u_synapse_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(syn_mem_addr_w),
        .o_read_weight(syn_mem_rdata_w),
        .i_write_en(1'b0), // Write disabled during operation
        .i_write_addr(0),
        .i_write_data(0)
    );

    // 4. Synapse Memory Controller - The Weight Fetcher
    synapse_mem_ctrl #(
        .DATA_WIDTH(WEIGHT_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .FIFO_DW(ADDR_WIDTH)
    ) u_synapse_mem_ctrl (
        .clk(clk), .rst_n(rst_n),
        .i_start_fetch(syn_fetch_start_w),
        .i_spike_addr_fifo_data(fifo_rdata_w),
        .i_spike_addr_fifo_valid(fifo_valid_w),
        .o_spike_addr_fifo_rden(fifo_rden_w),
        .i_syn_mem_rdata(syn_mem_rdata_w),
        .o_syn_mem_addr(syn_mem_addr_w),
        .o_weight_valid(syn_weight_valid_w),
        .o_weight_data(syn_weight_data_w),
        .o_fetch_done(syn_fetch_done_w)
    );

    // 5. MAC Unit - The Accumulator
    mac_unit #(
        .DATA_WIDTH(WEIGHT_WIDTH), .SUM_WIDTH(SUM_WIDTH)
    ) u_mac_unit (
        .clk(clk), .rst_n(rst_n),
        .i_clear(mac_clear_w),
        .i_accumulate(mac_accumulate_w),
        .i_data_in(syn_weight_data_w),
        .o_sum(mac_sum_w)
    );

    // 6. Neuron Body - The Processing Engine
    neuron_body #(
        .DATA_WIDTH(DATA_WIDTH)
        // ... Other parameters
    ) u_neuron_body (
        .clk(clk), .rst_n(rst_n),
        .in_valid(neuron_body_start_w),
        .in_mac_sum(neuron_body_mac_sum_w),
        // This is an abstract connection. In reality, the state is passed via main_ctrl
        // .in_state(neuron_body_state_in_w),
        // .out_state(neuron_body_state_out_w),
        .out_spike(neuron_body_spike_w)
        // ... Other ports
    );

    // 7. Input Spike Address FIFO - A simple behavioral model
    // In a real design, this would be a proper FIFO IP.
    // This FIFO holds the addresses of synapses that received a spike for the CURRENT neuron.
    spike_addr_fifo #(
        .DATA_WIDTH(ADDR_WIDTH), .DEPTH(128)
    ) u_spike_addr_fifo (
        .clk(clk), .rst_n(rst_n),
        .i_wr_en(i_spike_event_valid),
        .i_wdata(i_spike_event_addr),
        .i_rd_en(fifo_rden_w),
        .o_rdata(fifo_rdata_w),
        .o_valid(fifo_valid_w)
        // .o_full(), .o_empty()
    );

endmodule


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