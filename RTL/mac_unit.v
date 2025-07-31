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
    parameter DATA_WIDTH = 8,  // �Է� ����ġ �������� ��Ʈ ��
    parameter SUM_WIDTH  = 16  // ������ ���������� ��Ʈ �� (�����÷ο� ����)
)(
    // --- Global Ports ---
    input   wire                        clk,
    input   wire                        rst_n,

    // --- Control Interface from main_ctrl ---
    input   wire                        i_clear,      // �����⸦ 0���� �ʱ�ȭ
    input   wire                        i_accumulate, // �Է� �����͸� �����⿡ ����

    // --- Data Interface from synapse_mem_ctrl ---
    input   wire [DATA_WIDTH-1:0]       i_data_in,    // ���� ����ġ ��

    // --- Output Interface to main_ctrl ---
    output  reg  [SUM_WIDTH-1:0]        o_sum         // ���� ���� �հ�
);

    // ����� ���� ����
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            if (i_clear) begin
                // 1. �ʱ�ȭ: main_ctrl�� ������ ������ �� �����⸦ ���
                o_sum <= {SUM_WIDTH{1'b0}};
            end else if (i_accumulate) begin
                // 2. ����: ��ȿ�� ����ġ�� ���� ������ ����
                o_sum <= o_sum + i_data_in;
            end
        end
    end

endmodule
