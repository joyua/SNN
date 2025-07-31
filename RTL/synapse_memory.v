`timescale 1ns / 1ps
module synapse_memory #(
    parameter N_SYNAPSE = 10000,
    parameter DW = 8
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: �� ���� �ϳ��� �ε����� ���� ---
    input wire read_en,
    input wire [13:0] index_in,

    // --- Outputs: �ϳ��� ����ġ�� ��ȿ ��ȣ�� ��� ---
    output reg signed [DW-1:0] weight_out,
    output reg weight_valid_out
);

    // �ó��� ����ġ �޸� (signed Ÿ������ ����)
    reg signed [DW-1:0] mem [0:N_SYNAPSE-1];

    // �޸� �ʱ�ȭ (�ùķ��̼ǿ�)
    initial begin
        // synapse.hex ���Ͽ��� ����(������) ����ġ�� 2�� ���� ���·� ����Ǿ�� ��
        $readmemh("synapse.hex", mem);
    end

    // ����� �޸� �б� ���� (BRAM �𵨸�)
    // BRAM�� �ּҰ� ���� �� 1Ŭ�� �ڿ� �����Ͱ� ����
    always @(posedge clk) begin
        if (read_en) begin
            weight_out <= mem[index_in];
        end
    end

    // �б� ��ȿ ��ȣ ���������̴�
    // read_en ��ȣ�� �� Ŭ�� �������� ������ ��� ������ ����
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_valid_out <= 1'b0;
        end else begin
            weight_valid_out <= read_en;
        end
    end

endmodule