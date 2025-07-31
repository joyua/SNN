`timescale 1ns / 1ps
module SNN_prototype #(
    parameter N_SYNAPSE = 10000,
    parameter DW = 8,
    parameter ACCW = 8
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: AER(Address-Event Representation) ��� ---
    // ���� ������ũ�� �� Ÿ�ӽ��ܿ� ���������� ���´ٰ� ����
    input wire spike_valid_in, // ���� Ŭ���� ��ȿ�� ������ũ �ε����� ���Դ���
    input wire [13:0] spike_index_in, // ������ũ�� �߻���Ų ������ �ε���
    input wire spike_last_in, // �̹� Ÿ�ӽ����� ������ ������ũ���� ǥ��

    // --- Outputs ---
    output wire spike_out,
    output wire signed [ACCW-1:0] vmem_out
);

    // --- ���� ��ȣ ���� ---
    wire signed [DW-1:0] weight_data;
    wire weight_valid;
    reg  weight_last;

    // --- synapse_memory �ν��Ͻ� ---
    synapse_memory #(
        .N_SYNAPSE(N_SYNAPSE),
        .DW(DW)
    ) u_synapse_mem (
        .clk(clk),
        .rst_n(rst_n),
        .read_en(spike_valid_in),
        .index_in(spike_index_in),
        .weight_out(weight_data),
        .weight_valid_out(weight_valid)
    );

    // `synapse_memory`�� 1Ŭ�� ������ ���� `spike_last_in` ���� ��ȣ�� ������Ŵ
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_last <= 1'b0;
        end else begin
            // weight_valid�� AND�Ͽ� ��ȿ�� ������ ������ũ�� ����
            weight_last <= spike_last_in && spike_valid_in;
        end
    end

    // --- neuron_body �ν��Ͻ� ---
    neuron_body #(
        .DW(DW),
        .ACCW(ACCW)
    ) u_neuron_body (
        .clk(clk),
        .rst_n(rst_n),
        .weight_in(weight_data),
        .weight_valid_in(weight_valid),
        .weight_last_in(weight_last),
        .spike_out(spike_out),
        .vmem(vmem_out)
    );

endmodule