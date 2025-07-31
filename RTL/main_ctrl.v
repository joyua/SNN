`timescale 1ns / 1ps

//
// Module: main_ctrl
// Author: Gemini & User
// Version: 1.1
// Description:
//   The definitive main controller for the time-multiplexed SNN core.
//   It orchestrates all sub-modules (State Memory, Synapse Ctrl, MAC, Neuron Body)
//   and implements an event-driven loop to process multiple input spikes per neuron.
//
module main_ctrl #(
    // --- Parameters ---
    parameter DATA_WIDTH   = 8,
    parameter FSM_WIDTH    = 2,
    parameter NEURON_COUNT = 10000,
    parameter ADDR_WIDTH   = 14,
    // Packed state vector width (vmem, fsm_state, pre_spike_vmem)
    parameter STATE_VEC_WIDTH = DATA_WIDTH*2 + FSM_WIDTH
)(
    // --- Global Ports ---
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        i_global_start, // 전체 SNN 연산 시작

    // --- Neuron State Memory Interface ---
    output  reg  [ADDR_WIDTH-1:0]       o_neuron_state_addr,
    output  reg                         o_neuron_state_wr_en,
    output  reg  [STATE_VEC_WIDTH-1:0]  o_neuron_state_wdata,
    input   wire [STATE_VEC_WIDTH-1:0]  i_neuron_state_rdata,

    // --- Synapse Memory Controller Interface ---
    output  reg                         o_syn_fetch_start,
    input   wire                        i_syn_fetch_done,
    input   wire [DATA_WIDTH-1:0]       i_syn_weight_data,
    input   wire                        i_syn_weight_valid,

    // --- Input Spike Address FIFO Interface ---
    // (This controller assumes the synapse_mem_ctrl handles the FIFO)

    // --- MAC Unit Interface ---
    output  reg                         o_mac_clear,
    output  reg                         o_mac_accumulate,
    input   wire [DATA_WIDTH-1:0]       i_mac_sum,

    // --- Neuron Body (PE) Interface ---
    output  reg                         o_neuron_body_start,
    output  reg  [DATA_WIDTH-1:0]       o_neuron_body_mac_sum,
    output  reg  [STATE_VEC_WIDTH-1:0]  o_neuron_body_state_in,
    input   wire [STATE_VEC_WIDTH-1:0]  i_neuron_body_state_out,
    input   wire                        i_neuron_body_spike,

    // --- Output Spike Event Interface ---
    output  reg                         o_spike_out_valid,
    output  reg  [ADDR_WIDTH-1:0]       o_spike_out_addr,

    // --- Status Port ---
    output  reg                         o_snn_done
);

    // FSM State Definitions
    localparam S_IDLE                  = 4'd0;
    localparam S_FETCH_STATE           = 4'd1; // 1. 뉴런 상태 읽기 시작
    localparam S_WAIT_STATE_READ       = 4'd2; // 2. 뉴런 상태 읽기 대기
    localparam S_START_WEIGHT_FETCH    = 4'd3; // 3. 가중치 읽기 루프 시작
    localparam S_PROCESS_WEIGHTS       = 4'd4; // 4. 가중치 처리 및 MAC 누적
    localparam S_UPDATE_NEURON         = 4'd5; // 5. Neuron Body 연산 시작
    localparam S_WRITE_BACK            = 4'd6; // 6. 새로운 상태 저장
    localparam S_CHECK_SPIKE           = 4'd7; // 7. 스파이크 출력 확인
    localparam S_NEXT_NEURON           = 4'd8; // 8. 다음 뉴런으로
    localparam S_DONE                  = 4'd9;

    // Internal Registers
    reg [3:0] current_state, next_state;
    reg [ADDR_WIDTH-1:0] neuron_idx;
    reg [STATE_VEC_WIDTH-1:0] current_neuron_state;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S_IDLE;
        else        current_state <= next_state;
    end

    // FSM Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE:                 if (i_global_start) next_state = S_FETCH_STATE;
            S_FETCH_STATE:          next_state = S_WAIT_STATE_READ;
            S_WAIT_STATE_READ:      next_state = S_START_WEIGHT_FETCH;
            S_START_WEIGHT_FETCH:   next_state = S_PROCESS_WEIGHTS;
            S_PROCESS_WEIGHTS:      if (i_syn_fetch_done) next_state = S_UPDATE_NEURON; // 가중치 처리 루프 완료
            S_UPDATE_NEURON:        next_state = S_WRITE_BACK;
            S_WRITE_BACK:           next_state = S_CHECK_SPIKE;
            S_CHECK_SPIKE:          next_state = S_NEXT_NEURON;
            S_NEXT_NEURON:          if (neuron_idx == NEURON_COUNT - 1) next_state = S_DONE;
                                    else next_state = S_FETCH_STATE;
            S_DONE:                 next_state = S_IDLE;
            default:                next_state = S_IDLE;
        endcase
    end

    // Control Signals and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers and outputs
            o_neuron_state_addr  <= 0;
            o_neuron_state_wr_en <= 1'b0;
            o_neuron_state_wdata <= 0;
            o_syn_fetch_start    <= 1'b0;
            o_mac_clear          <= 1'b1;
            o_mac_accumulate     <= 1'b0;
            o_neuron_body_start  <= 1'b0;
            o_neuron_body_mac_sum<= 0;
            o_neuron_body_state_in <= 0;
            o_spike_out_valid    <= 1'b0;
            o_spike_out_addr     <= 0;
            o_snn_done           <= 1'b0;
            neuron_idx           <= 0;
            current_neuron_state <= 0;
        end else begin
            // Default assignments for pulse signals
            o_neuron_state_wr_en <= 1'b0;
            o_syn_fetch_start    <= 1'b0;
            o_mac_clear          <= 1'b0;
            o_mac_accumulate     <= 1'b0;
            o_neuron_body_start  <= 1'b0;
            o_spike_out_valid    <= 1'b0;
            o_snn_done           <= 1'b0;

            case (current_state)
                S_IDLE: begin
                    if (i_global_start) neuron_idx <= 0;
                end

                S_FETCH_STATE: begin
                    o_neuron_state_addr <= neuron_idx;
                end

                S_WAIT_STATE_READ: begin
                    current_neuron_state <= i_neuron_state_rdata;
                    o_mac_clear <= 1'b1; // MAC 누적기 초기화
                end

                S_START_WEIGHT_FETCH: begin
                    o_syn_fetch_start <= 1'b1; // synapse_mem_ctrl에 가중치 fetch 루프 시작 요청
                end

                S_PROCESS_WEIGHTS: begin
                    if (i_syn_weight_valid) begin
                        o_mac_accumulate <= 1'b1; // 유효한 가중치가 들어오면 MAC 누적
                    end
                end

                S_UPDATE_NEURON: begin
                    o_neuron_body_start <= 1'b1;
                    o_neuron_body_mac_sum <= i_mac_sum; // 최종 가중합 전달
                    o_neuron_body_state_in <= current_neuron_state; // 읽어뒀던 현재 상태 전달
                end

                S_WRITE_BACK: begin
                    o_neuron_state_wr_en <= 1'b1;
                    o_neuron_state_addr <= neuron_idx;
                    o_neuron_state_wdata <= i_neuron_body_state_out; // neuron_body의 새 상태를 저장
                end

                S_CHECK_SPIKE: begin
                    if (i_neuron_body_spike) begin
                        o_spike_out_valid <= 1'b1;
                        o_spike_out_addr <= neuron_idx;
                    end
                end

                S_NEXT_NEURON: begin
                    neuron_idx <= neuron_idx + 1;
                end

                S_DONE: begin
                    o_snn_done <= 1'b1;
                end
            endcase
        end
    end

endmodule
