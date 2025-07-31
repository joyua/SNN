`timescale 1ns / 1ps
module synapse_memory #(
    parameter N_SYNAPSE = 10000,
    parameter DW = 8
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: 한 번에 하나의 인덱스를 받음 ---
    input wire read_en,
    input wire [13:0] index_in,

    // --- Outputs: 하나의 가중치와 유효 신호를 출력 ---
    output reg signed [DW-1:0] weight_out,
    output reg weight_valid_out
);

    // 시냅스 가중치 메모리 (signed 타입으로 선언)
    reg signed [DW-1:0] mem [0:N_SYNAPSE-1];

    // 메모리 초기화 (시뮬레이션용)
    initial begin
        // synapse.hex 파일에는 음수(억제성) 가중치가 2의 보수 형태로 저장되어야 함
        $readmemh("synapse.hex", mem);
    end

    // 동기식 메모리 읽기 로직 (BRAM 모델링)
    // BRAM은 주소가 들어온 후 1클럭 뒤에 데이터가 나옴
    always @(posedge clk) begin
        if (read_en) begin
            weight_out <= mem[index_in];
        end
    end

    // 읽기 유효 신호 파이프라이닝
    // read_en 신호를 한 클럭 지연시켜 데이터 출력 시점과 맞춤
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_valid_out <= 1'b0;
        end else begin
            weight_valid_out <= read_en;
        end
    end

endmodule