`timescale 1ns / 1ps

//
// Module: mac_unit
// Author: Gemini & User
// Version: 1.0
// Description:
//   A basic, extensible MAC (Accumulate) unit for the SNN core.
//   It accumulates input weights based on control signals.
//   This modular design allows for future PPA optimizations (e.g., pipelining)
//   by replacing only this module without affecting the main controller.
//
module mac_unit #(
    // --- Parameters ---
    parameter DATA_WIDTH = 8,  // 입력 가중치 데이터의 비트 폭
    parameter SUM_WIDTH  = 16  // 누적기 레지스터의 비트 폭 (오버플로우 방지)
)(
    // --- Global Ports ---
    input   wire                        clk,
    input   wire                        rst_n,

    // --- Control Interface from main_ctrl ---
    input   wire                        i_clear,      // 누적기를 0으로 초기화
    input   wire                        i_accumulate, // 입력 데이터를 누적기에 더함

    // --- Data Interface from synapse_mem_ctrl ---
    input   wire [DATA_WIDTH-1:0]       i_data_in,    // 더할 가중치 값

    // --- Output Interface to main_ctrl ---
    output  reg  [SUM_WIDTH-1:0]        o_sum         // 최종 누적 합계
);

    // 동기식 누적 로직
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            if (i_clear) begin
                // 1. 초기화: main_ctrl이 루프를 시작할 때 누적기를 비움
                o_sum <= {SUM_WIDTH{1'b0}};
            end else if (i_accumulate) begin
                // 2. 누적: 유효한 가중치가 들어올 때마다 더함
                o_sum <= o_sum + i_data_in;
            end
        end
    end

endmodule
