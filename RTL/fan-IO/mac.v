`timescale 1ns / 1ps

//
// Module: mac
// Description: A standard Multiply-Accumulate (MAC) unit for SNNs. In this context,
//              it primarily performs accumulation, as the multiplication by a spike (0 or 1)
//              is handled implicitly by the controller. It sums up to 128 weights.
//
module mac #(
    // --- Parameters ---
    parameter DATA_WIDTH = 8,    // �Է� ����ġ �������� ��Ʈ �� (signed)
    parameter SUM_WIDTH  = 16    // ������ ���������� ��Ʈ �� (�����÷ο� ����)
                                 // 8-bit * 128 = 10240, 16-bit is sufficient.
)(
    // --- Global Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Control Interface (from synapse_mem_ctrl) ---
    input  wire                      i_clear,      // �����⸦ 0���� �ʱ�ȭ
    input  wire                      i_accumulate, // ��ȿ�� ����ġ�� ����

    // --- Data Interface ---
    input  wire signed [DATA_WIDTH-1:0] i_syn_weight, // ���� ����ġ ��

    // --- Output ---
    output reg  signed [SUM_WIDTH-1:0]   o_sum         // ���� ���� �հ�
);

    // --- Synchronous Accumulation Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 1. �񵿱� ����: �ý��� ���� �� �����⸦ 0���� �ʱ�ȭ
            o_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            if (i_clear) begin
                // 2. ����� �ʱ�ȭ: ���ο� ������ ��� ���� ��, �����⸦ ���
                o_sum <= {SUM_WIDTH{1'b0}};
            end else if (i_accumulate) begin
                // 3. ����: ��ȿ�� ����ġ�� ���� ������ ���� �տ� ����
                o_sum <= o_sum + i_syn_weight;
            end
            // ���� ��ȣ�� ������, o_sum �������ʹ� ���� ���� �����մϴ�.
        end
    end

endmodule
