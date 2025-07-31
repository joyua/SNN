`timescale 1ns / 1ps
module neuron_body #(
    parameter DW = 8,
    parameter ACCW = 8,
    parameter RELREF_DUR = 8,
    parameter ABSREF_DUR = 16
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: 순차적으로 가중치와 제어 신호를 받음 ---
    input wire signed [DW-1:0] weight_in,
    input wire weight_valid_in,
    input wire weight_last_in, // 현재 가중치가 이번 타임스텝의 마지막인지 표시

    // --- Outputs ---
    output reg spike_out,
    output reg signed [ACCW-1:0] vmem
);

    // FSM 상태 정의
    localparam S_IDLE      = 3'b000;
    localparam S_ACCUM     = 3'b001; // 가중치 누적 상태
    localparam S_INTEGRATE = 3'b010; // 막전위 계산 상태
    localparam S_FIRE      = 3'b011;
    localparam S_RELREF    = 3'b100;
    localparam S_ABSREF    = 3'b101;

    reg [2:0] state, next_state;
    
    // 뉴런 파라미터 (Q4.4 포맷)
    localparam signed [ACCW-1:0] VMEM_INIT = -16; // -1.0
    localparam signed [ACCW-1:0] VTH       = 8;   // 0.5
    localparam signed [ACCW-1:0] OVERSHOOT = 0;
    localparam signed [ACCW-1:0] LEAK      = 1;   // 0.0625

    // 내부 레지스터
    reg signed [ACCW+7:0] mac_reg; // 가중치 누적기
    reg [7:0] ref_cnt;             // 불응기 타이머
    
    // [오류 수정] wire -> reg로 변경
    reg signed [ACCW-1:0] vmem_next;

    // --- 다음 상태(next_state) 및 다음 막전위(vmem_next) 계산을 위한 조합 논리 ---
    always @(*) begin
        next_state = state;
        vmem_next = vmem;
        spike_out = 1'b0;

        case (state)
            S_IDLE: begin
                if (weight_valid_in) begin
                    next_state = S_ACCUM;
                end
            end
            S_ACCUM: begin
                if (weight_last_in && weight_valid_in) begin
                    next_state = S_INTEGRATE;
                end
            end
            S_INTEGRATE: begin
                // vmem_next는 현재 vmem과 누적된 mac_reg를 기반으로 계산
                vmem_next = vmem + mac_reg - LEAK;
                if (vmem_next >= VTH) begin
                    next_state = S_FIRE;
                end else begin
                    next_state = S_IDLE;
                end
            end
            S_FIRE: begin
                spike_out = 1'b1;
                // vmem 값에 따라 불응기 상태 결정
                if (vmem >= OVERSHOOT) begin
                    next_state = S_ABSREF;
                end else begin
                    next_state = S_RELREF;
                end
            end
            S_RELREF: begin
                vmem_next = vmem - (LEAK + 1); // 더 강한 누수
                if (ref_cnt == 1) next_state = S_IDLE;
            end
            S_ABSREF: begin
                vmem_next = vmem - (LEAK + 2); // 가장 강한 누수
                if (ref_cnt == 1) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end
    
    // --- FSM과 레지스터 업데이트를 위한 순차 논리 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            vmem    <= VMEM_INIT;
            mac_reg <= 0;
            ref_cnt <= 0;
        end else begin
            state <= next_state;

            // vmem 업데이트
            // S_INTEGRATE, S_RELREF, S_ABSREF 상태에서 vmem_next 값으로 업데이트
            if (next_state == S_INTEGRATE || next_state == S_RELREF || next_state == S_ABSREF) begin
                vmem <= vmem_next;
            end
            
            // mac_reg 업데이트
            if (state == S_IDLE && next_state == S_ACCUM) begin
                 mac_reg <= $signed(weight_in); // 누적 시작
            end else if (state == S_ACCUM) begin
                 if(weight_valid_in) mac_reg <= mac_reg + $signed(weight_in);
            end else if (state == S_INTEGRATE) begin
                mac_reg <= 0; // 누적기 초기화
            end

            // ref_cnt 업데이트
            if (next_state == S_RELREF) begin
                if(state != S_RELREF) ref_cnt <= RELREF_DUR;
                else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1;
            end else if (next_state == S_ABSREF) begin
                if(state != S_ABSREF) ref_cnt <= ABSREF_DUR;
                else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1;
            end else begin
                ref_cnt <= 0;
            end

            // 불응기 종료 시 vmem 리셋
            if(ref_cnt == 1) vmem <= VMEM_INIT; 
        end
    end

endmodule