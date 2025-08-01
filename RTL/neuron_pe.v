`timescale 1ns / 1ps

//
// Module: neuron_pe
// Version: 2.3 (Final, Behavior-Matched - Corrected MAX_VAL logic)
// Description: A stateless PE that perfectly mimics the behavior of the user's
//              stateful 'neuron_body' module, including the special MAX_VAL logic.
//
module neuron_pe #(
    // --- Architectural Parameters ---
    parameter DATA_WIDTH      = 8,
    parameter FSM_WIDTH       = 2,
    parameter SUM_WIDTH       = 16,
    // --- State Vector: {vmem, fsm_state, vmem_prev} ---
    parameter STATE_VEC_WIDTH = DATA_WIDTH + FSM_WIDTH + DATA_WIDTH,

    // --- Neuron Behavior Parameters (from user's neuron_body) ---
    parameter THRESH          = 15,
    parameter THRESH_HIGH     = 40,
    parameter MAX_VAL         = 100,
    parameter LEAK_IDLE       = 2,
    parameter LEAK_REF        = 20
)(
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        i_start,
    input   wire [SUM_WIDTH-1:0]        i_mac_sum,
    input   wire [STATE_VEC_WIDTH-1:0]  i_state_in,
    output  reg  [STATE_VEC_WIDTH-1:0]  o_state_out,
    output  reg                         o_spike
);

    // FSM State Definitions
    localparam S_IDLE    = 2'd0;
    localparam S_SPIKE   = 2'd1;
    localparam S_REL_REF = 2'd2;
    localparam S_ABS_REF = 2'd3;

    // --- Unpack Input State Vector ---
    wire [DATA_WIDTH-1:0] current_vmem;
    wire [FSM_WIDTH-1:0]  current_fsm_state;
    wire [DATA_WIDTH-1:0] current_vmem_prev;
    assign {current_vmem, current_fsm_state, current_vmem_prev} = i_state_in;

    // --- Internal Registers for Next State Calculation ---
    reg [DATA_WIDTH-1:0] next_vmem;
    reg [FSM_WIDTH-1:0]  next_fsm_state;
    reg [DATA_WIDTH-1:0] next_vmem_prev;
    
            // 2. Datapath Logic (from user's neuron_body)
    reg [DATA_WIDTH:0] tmp_sum;
    reg [DATA_WIDTH-1:0] vmem_after_update; // 중간 계산 결과 저장용

    // --- Combinational Logic to Calculate Next State ---
    always @(*) begin
        // Default assignments
        next_vmem           = current_vmem;
        next_fsm_state      = current_fsm_state;
        next_vmem_prev      = current_vmem; // 다음 상태의 '이전 값'은 현재 값이 됨

        // 1. FSM Next State Logic (from user's neuron_body)
        case (current_fsm_state)
            S_IDLE:     if (current_vmem >= THRESH) next_fsm_state = S_SPIKE;
            S_SPIKE:    next_fsm_state = S_ABS_REF;
            S_ABS_REF:  if (current_vmem <= 70) next_fsm_state = S_REL_REF;
            S_REL_REF:  if (current_vmem == 0) next_fsm_state = S_IDLE;
                        else if (current_vmem >= THRESH_HIGH && i_start) next_fsm_state = S_SPIKE;
            default:    next_fsm_state = S_IDLE;
        endcase


        case (current_fsm_state)
            S_IDLE: begin
                if (i_start) begin
                    tmp_sum = current_vmem + i_mac_sum;
                    if (tmp_sum > LEAK_IDLE) begin
                        tmp_sum = tmp_sum - LEAK_IDLE;
                        if (tmp_sum >= MAX_VAL) vmem_after_update = MAX_VAL;
                        else vmem_after_update = tmp_sum[DATA_WIDTH-1:0];
                    end else begin
                        vmem_after_update = 0;
                    end
                end else begin
                    if (current_vmem > LEAK_IDLE) vmem_after_update = current_vmem - LEAK_IDLE;
                    else vmem_after_update = 0;
                end
                
                // --- <<< 수정된 핵심 로직 >>> ---
                // Special logic: Clamp to MAX_VAL when threshold is crossed
                // '업데이트 전 vmem'과 '업데이트 후 vmem'을 비교하여 최종 next_vmem 결정
                if ((current_vmem < THRESH) && (vmem_after_update >= THRESH)) begin
                    next_vmem = MAX_VAL;
                end else begin
                    next_vmem = vmem_after_update;
                end
            end
            S_SPIKE: begin
                o_spike = 1'b1;
                next_vmem = current_vmem;
            end
            S_ABS_REF: begin
                if (current_vmem > LEAK_REF) next_vmem = current_vmem - LEAK_REF;
                else next_vmem = 0;
            end
            S_REL_REF: begin
                if (i_start) begin
                    tmp_sum = current_vmem + i_mac_sum;
                    if (tmp_sum > LEAK_REF) begin
                        tmp_sum = tmp_sum - LEAK_REF;
                        if (tmp_sum >= MAX_VAL) vmem_after_update = MAX_VAL;
                        else vmem_after_update = tmp_sum[DATA_WIDTH-1:0];
                    end else begin
                        vmem_after_update = 0;
                    end
                end else begin
                    if (current_vmem > LEAK_REF) vmem_after_update = current_vmem - LEAK_REF;
                    else vmem_after_update = 0;
                end
                
                // --- <<< 수정된 핵심 로직 >>> ---
                // Special logic: Clamp to MAX_VAL on re-fire
                if ((current_vmem < THRESH_HIGH) && (vmem_after_update >= THRESH_HIGH)) begin
                    next_vmem = MAX_VAL;
                end else begin
                    next_vmem = vmem_after_update;
                end
            end
        endcase
    end

    // --- Output Registers (for synchronous output) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_state_out <= 0;
            o_spike     <= 1'b0;
        end else begin
            o_state_out <= {next_vmem, next_fsm_state, next_vmem_prev};
            o_spike     <= (current_fsm_state == S_SPIKE);
        end
    end

endmodule
