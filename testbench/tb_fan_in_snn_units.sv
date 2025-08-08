`timescale 1ns / 1ps

//
// Module: tb_fan_in_snn_units
// Description: A comprehensive SystemVerilog testbench to test the integration of all
//              fan-in neuron components: controller, memories, MAC, and PU.
//
module tb_fan_in_snn_units;

    // --- Parameters ---
    localparam ADDR_WIDTH    = 14;
    localparam VMEM_WIDTH    = 16;
    localparam REF_CTR_WIDTH = 4;
    localparam DATA_WIDTH    = 8;
    localparam SUM_WIDTH     = 16;
    localparam FIFO_DEPTH    = 256;
    localparam SOURCE_NEURON_ADDR = 0;

    // --- Testbench Signals ---
    logic                      clk;
    logic                      rst_n;
    logic                      start_processing;
    
    // FIFO Interface
    logic                      fifo_wr_en;
    logic [ADDR_WIDTH-1:0]     fifo_wr_data;
    wire                       fifo_full;
    wire                       fifo_empty;
    wire [ADDR_WIDTH-1:0]      fifo_rd_data;
    
    // Other wires for inter-module connections
    wire                       processing_done;
    wire                       fifo_rd_en;
    wire [ADDR_WIDTH-1:0]      syn_mem_addr;
    wire signed [DATA_WIDTH-1:0] weight_from_mem;
    wire                       mac_clear;
    wire                       mac_accumulate;
    wire signed [SUM_WIDTH-1:0]  mac_sum_out;
    wire [ADDR_WIDTH-1:0]      neuron_mem_rd_addr;
    wire [ADDR_WIDTH-1:0]      neuron_mem_wr_addr;
    wire                       neuron_mem_wr_en;
    wire signed [VMEM_WIDTH-1:0] vmem_from_mem;
    wire [REF_CTR_WIDTH-1:0]  ref_ctr_from_mem;
    wire                       pu_in_valid;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_out;
    wire [REF_CTR_WIDTH-1:0]  pu_ref_ctr_out;
    wire signed [VMEM_WIDTH-1:0] pu_vmem_in;
    wire [REF_CTR_WIDTH-1:0]  pu_ref_ctr_in;
    wire signed [SUM_WIDTH-1:0]  pu_syn_current_in;
    wire                       final_spike; // The actual spike output from the PU

    integer                  error_count;

    //================================================================
    // --- 1. DUT Instantiations ---
    //================================================================

    // --- Spike Input FIFO ---
    spike_fifo #( .DATA_WIDTH(ADDR_WIDTH), .DEPTH(FIFO_DEPTH) )
    u_spike_fifo (
        .clk(clk), .rst_n(rst_n), .i_wr_en(fifo_wr_en), .i_wr_data(fifo_wr_data),
        .i_rd_en(fifo_rd_en), .o_rd_data(fifo_rd_data), .o_empty(fifo_empty),
        .o_full(fifo_full), .o_count()
    );

    // --- Source Controller ---
    source_controller u_controller (
        .clk(clk), .rst_n(rst_n), .i_start_processing(start_processing),
        .o_processing_done(processing_done), .o_spike_fifo_rden(fifo_rd_en),
        .i_spike_fifo_rdata(fifo_rd_data), .i_spike_fifo_empty(fifo_empty),
        .o_synapse_mem_addr(syn_mem_addr), .i_weight_from_mem(weight_from_mem),
        .o_mac_clear(mac_clear), .o_mac_accumulate(mac_accumulate),
        .i_mac_sum_out(mac_sum_out), .o_neuron_mem_rd_addr(neuron_mem_rd_addr),
        .o_neuron_mem_wr_addr(neuron_mem_wr_addr), .o_neuron_mem_wr_en(neuron_mem_wr_en),
        .i_vmem_from_mem(vmem_from_mem), .i_ref_ctr_from_mem(ref_ctr_from_mem),
        .o_pu_in_valid(pu_in_valid), .i_pu_vmem_out(pu_vmem_out),
        .i_pu_ref_ctr_out(pu_ref_ctr_out), .o_pu_vmem_in(pu_vmem_in),
        .o_pu_ref_ctr_in(pu_ref_ctr_in), .o_pu_syn_current_in(pu_syn_current_in)
    );

    // --- Synapse Memory ---
    synapse_mem #( .DEPTH(10000), .INIT_FILE("weight_init.mem") )
    u_synapse_mem (
        .clk(clk), .i_rd_addr(syn_mem_addr), .o_rd_data(weight_from_mem)
    );

    // --- Neuron State Memory ---
    neuron_lutram #( .NUM_NEURONS(128) )
    u_neuron_mem (
        .clk(clk), .rst_n(rst_n),
        .i_wr_en(neuron_mem_wr_en), .i_wr_addr(neuron_mem_wr_addr),
        .i_vmem_in(pu_vmem_out), .i_ref_ctr_in(pu_ref_ctr_out),
        .i_rd_addr(neuron_mem_rd_addr), .o_vmem_out(vmem_from_mem),
        .o_ref_ctr_out(ref_ctr_from_mem)
    );

    // --- MAC Accumulator ---
    mac u_mac (
        .clk(clk), .rst_n(rst_n), .i_clear(mac_clear),
        .i_accumulate(mac_accumulate), .i_syn_weight(weight_from_mem),
        .o_sum(mac_sum_out)
    );
    
    // --- Neuron Processing Unit ---
    neuron_pu #( .DATA_WIDTH(SUM_WIDTH) ) // DATA_WIDTH must match MAC's SUM_WIDTH
    u_neuron_pu (
        .clk(clk), .rst_n(rst_n), .i_in_valid(pu_in_valid),
        .i_vmem_in(pu_vmem_in), .i_ref_ctr_in(pu_ref_ctr_in),
        .i_syn_current(pu_syn_current_in), .o_spike(final_spike),
        .o_vmem_out(pu_vmem_out), .o_ref_ctr_out(pu_ref_ctr_out)
    );

    // Clock and Reset Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //================================================================
    // --- 2. Reusable Test Tasks ---
    //================================================================
    task apply_reset();
        rst_n = 1'b0;
        start_processing = 1'b0;
        fifo_wr_en = 1'b0;
        fifo_wr_data = '0;
        error_count = 0;
        #20ns;
        rst_n = 1'b1;
        $display("[%0t] 시스템 리셋 완료.", $time);
        @(posedge clk);
    endtask

    task write_fifo(input logic [ADDR_WIDTH-1:0] addr);
        wait(!fifo_full);
        fifo_wr_en = 1;
        fifo_wr_data = addr;
        @(posedge clk);
        fifo_wr_en = 0;
    endtask

    task trigger_and_wait();
        start_processing = 1;
        @(posedge clk);
        start_processing = 0;
        wait(processing_done);
        $display("[%0t] 처리 완료 신호 수신.", $time);
        @(posedge clk);
    endtask

    //================================================================
    // --- 3. Main Test Sequence ---
    //================================================================
    initial begin
        $dumpfile("fan_in_units.vcd");
        $dumpvars(0, tb_fan_in_snn_units);
        
        apply_reset();

        // --- SCENARIO 1: No spikes in FIFO ---
        $display("\n[%0t] SCENARIO 1: FIFO가 비어있을 때 시작", $time);
        trigger_and_wait();
        if (mac_sum_out == 0) $display("    - 성공: MAC 합계가 0으로 유지됨.");
        else $error("    - 실패: MAC 합계가 0이 아님!");

        // --- SCENARIO 2: Sum < Threshold (No Spike) ---
        $display("\n[%0t] SCENARIO 2: 가중합 < 임계값 (스파이크 미발생)", $time);
        write_fifo(14'h000A); // Weight 50
        write_fifo(14'h000B); // Weight 60
        trigger_and_wait();
        if (mac_sum_out == 110) $display("    - 성공: MAC 합계(110) 정확함.");
        else $error("    - 실패: MAC 합계가 110이 아님!");
        if (!final_spike) $display("    - 성공: 최종 스파이크 미발생.");
        else $error("    - 실패: 스파이크가 잘못 발생함!");

        // --- SCENARIO 3: Sum > Threshold (Spike) ---
        $display("\n[%0t] SCENARIO 3: 가중합 > 임계값 (스파이크 발생)", $time);
        write_fifo(14'h0014); // Weight 70
        write_fifo(14'h0015); // Weight 80
        write_fifo(14'h0016);
        write_fifo(14'h000A);
        trigger_and_wait();
        if (mac_sum_out >= 150) $display("    - 성공: MAC 합계(150) 정확함.");
        else $error("    - 실패: MAC 합계가 150이 아님!");
        if (final_spike) $display("    - 성공: 최종 스파이크 발생!");
        else $error("    - 실패: 스파이크가 발생하지 않음!");

        #100ns;
        $display("\n--- 모든 테스트 완료 ---");
        $finish;
    end

endmodule
