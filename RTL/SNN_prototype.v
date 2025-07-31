`timescale 1ns / 1ps
module SNN_prototype #(
    parameter N_SYNAPSE = 10000,
    parameter DW = 8,
    parameter ACCW = 8
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: AER(Address-Event Representation) 방식 ---
    // 여러 스파이크가 한 타임스텝에 순차적으로 들어온다고 가정
    input wire spike_valid_in, // 현재 클럭에 유효한 스파이크 인덱스가 들어왔는지
    input wire [13:0] spike_index_in, // 스파이크를 발생시킨 뉴런의 인덱스
    input wire spike_last_in, // 이번 타임스텝의 마지막 스파이크인지 표시

    // --- Outputs ---
    output wire spike_out,
    output wire signed [ACCW-1:0] vmem_out
);

    // --- 내부 신호 선언 ---
    wire signed [DW-1:0] weight_data;
    wire weight_valid;
    reg  weight_last;

    // --- synapse_memory 인스턴스 ---
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

    // `synapse_memory`의 1클럭 지연에 맞춰 `spike_last_in` 제어 신호를 지연시킴
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_last <= 1'b0;
        end else begin
            // weight_valid와 AND하여 유효한 마지막 스파이크만 전달
            weight_last <= spike_last_in && spike_valid_in;
        end
    end

    // --- neuron_body 인스턴스 ---
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