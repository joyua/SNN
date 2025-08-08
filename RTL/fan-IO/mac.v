`timescale 1ns / 1ps

//
// Module: mac
// Description: A standard Multiply-Accumulate (MAC) unit for SNNs. In this context,
//              it primarily performs accumulation, as the multiplication by a spike (0 or 1)
//              is handled implicitly by the controller. It sums up to 128 weights.
//
module mac #(
    // --- Parameters ---
    parameter DATA_WIDTH = 8,    // 입력 가중치 데이터의 비트 폭 (signed)
    parameter SUM_WIDTH  = 16    // 누적기 레지스터의 비트 폭 (오버플로우 방지)
                                 // 8-bit * 128 = 10240, 16-bit is sufficient.
)(
    // --- Global Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Control Interface (from synapse_mem_ctrl) ---
    input  wire                      i_clear,      // 누적기를 0으로 초기화
    input  wire                      i_accumulate, // 유효한 가중치를 누적

    // --- Data Interface ---
    input  wire signed [DATA_WIDTH-1:0] i_syn_weight, // 더할 가중치 값

    // --- Output ---
    output reg  signed [SUM_WIDTH-1:0]   o_sum         // 최종 누적 합계
);

    // --- Synchronous Accumulation Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 1. 비동기 리셋: 시스템 리셋 시 누적기를 0으로 초기화
            o_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            if (i_clear) begin
                // 2. 동기식 초기화: 새로운 가중합 계산 시작 전, 누적기를 비움
                o_sum <= {SUM_WIDTH{1'b0}};
            end else if (i_accumulate) begin
                // 3. 누적: 유효한 가중치가 들어올 때마다 현재 합에 더함
                o_sum <= o_sum + i_syn_weight;
            end
            // 제어 신호가 없으면, o_sum 레지스터는 기존 값을 유지합니다.
        end
    end

endmodule
