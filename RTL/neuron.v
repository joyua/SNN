`timescale 1ns / 1ps

//
// Module: neuron
// Author: Gemini & User
// Version: 1.4
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
    output  wire                        o_snn_done,

    // --- Debug Port ---
    output  wire [ADDR_WIDTH-1:0]       o_debug_current_neuron_idx
);

    // --- Internal Wires for Inter-module Connection ---
    wire [ADDR_WIDTH-1:0]       state_mem_addr_w;
    wire                        state_mem_wr_en_w;
    wire [STATE_VEC_WIDTH-1:0]  state_mem_wdata_w;
    wire [STATE_VEC_WIDTH-1:0]  state_mem_rdata_w;
    wire                        syn_fetch_start_w;
    wire                        syn_fetch_done_w;
    wire [WEIGHT_WIDTH-1:0]     syn_weight_data_w;
    wire                        syn_weight_valid_w;
    wire [ADDR_WIDTH-1:0]       syn_mem_addr_w;
    wire [WEIGHT_WIDTH-1:0]     syn_mem_rdata_w;
    wire [ADDR_WIDTH-1:0]       fifo_rdata_w;
    wire                        fifo_valid_w;
    wire                        fifo_rden_w;
    wire                        mac_clear_w;
    wire                        mac_accumulate_w;
    wire [SUM_WIDTH-1:0]        mac_sum_w;
    wire                        pe_start_w;
    wire [SUM_WIDTH-1:0]        pe_mac_sum_w;
    wire [STATE_VEC_WIDTH-1:0]  pe_state_in_w;
    wire [STATE_VEC_WIDTH-1:0]  pe_state_out_w;
    wire                        pe_spike_w;
    wire [ADDR_WIDTH-1:0]       main_ctrl_current_idx_w;


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
        .o_neuron_state_wdata(pe_state_out_w),
        .i_neuron_state_rdata(state_mem_rdata_w),
        .o_syn_fetch_start(syn_fetch_start_w),
        .i_syn_fetch_done(syn_fetch_done_w),
        .i_syn_weight_data(syn_weight_data_w),
        .i_syn_weight_valid(syn_weight_valid_w),
        .o_mac_clear(mac_clear_w),
        .o_mac_accumulate(mac_accumulate_w),
        .i_mac_sum(mac_sum_w),
    
        // --- <<< 수정된 부분 시작 >>> ---
        .o_pe_start(pe_start_w),
        .o_pe_mac_sum(mac_sum_w),
        .o_pe_state_in(state_mem_rdata_w),
        .i_pe_state_out(pe_state_out_w),
        .i_pe_spike(pe_spike_w),
        // --- <<< 수정된 부분 끝 >>> ---
    
        .o_spike_out_valid(o_spike_out_valid),
        .o_spike_out_addr(o_spike_out_addr),
        .o_snn_done(o_snn_done),
        .o_current_neuron_idx(main_ctrl_current_idx_w)
    );

    // 2. Neuron State Memory - The Neuron Register File
    neuron_state_memory #(
        .NEURON_COUNT(NEURON_COUNT), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .FSM_WIDTH(FSM_WIDTH)
    ) u_neuron_state_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(state_mem_addr_w),
        .o_read_data(state_mem_rdata_w),
        .i_write_en(state_mem_wr_en_w),
        .i_write_addr(state_mem_addr_w),
        .i_write_data(pe_state_out_w)
    );

    // 3. Synapse Memory - The Weight Database
    synapse_memory #(
        .DATA_WIDTH(WEIGHT_WIDTH), .DEPTH(NEURON_COUNT*1), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_synapse_mem (
        .clk(clk), .rst_n(rst_n),
        .i_read_addr(syn_mem_addr_w),
        .o_read_weight(syn_mem_rdata_w),
        .i_write_en(1'b0),
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

    // 6. Neuron Processing Element (PE) - The Stateless Calculator
    neuron_pe #(
        .DATA_WIDTH(DATA_WIDTH), .FSM_WIDTH(FSM_WIDTH), .SUM_WIDTH(SUM_WIDTH), .STATE_VEC_WIDTH(STATE_VEC_WIDTH)
    ) u_neuron_pe (
        .clk(clk), .rst_n(rst_n),
        .i_start(pe_start_w),
        .i_mac_sum(mac_sum_w),
        .i_state_in(state_mem_rdata_w),
        .o_state_out(pe_state_out_w),
        .o_spike(pe_spike_w)
    );

    // 7. Input Spike Address FIFO
    spike_addr_fifo #(
        .DATA_WIDTH(ADDR_WIDTH), .DEPTH(128)
    ) u_spike_addr_fifo (
        .clk(clk), .rst_n(rst_n),
        .i_wr_en(i_spike_event_valid),
        .i_wdata(i_spike_event_addr),
        .i_rd_en(fifo_rden_w),
        .o_rdata(fifo_rdata_w),
        .o_valid(fifo_valid_w)
    );

    // --- Debug Port Assignment ---
    assign o_debug_current_neuron_idx = main_ctrl_current_idx_w;

endmodule
