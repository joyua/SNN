`timescale 1ns / 1ps

//
// Module: source_neuron_lutram
// Description: A small, efficient state memory for a group of source neurons,
//              intended to be synthesized as LUTRAM (Distributed RAM) in an FPGA.
//              It uses a simple dual-port structure (1 Write, 1 Read) to allow
//              simultaneous read and write operations required by a TDM controller.
//
module neuron_lutram #(
    // --- Configuration Parameters ---
    parameter NUM_NEURONS   = 128,    // 저장할 총 소스 뉴런의 개수
    parameter VMEM_WIDTH    = 16,     // 막전위(Vmem)의 비트 폭
    parameter REF_CTR_WIDTH = 4       // 불응기 카운터의 비트 폭
)(
    // --- Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Write Port (from Controller, with data from PU) ---
    input  wire                      i_wr_en,      // 쓰기 활성화
    input  wire [$clog2(NUM_NEURONS)-1:0] i_wr_addr,    // 쓸 뉴런의 주소
    input  wire signed [VMEM_WIDTH-1:0] i_vmem_in,    // 쓸 새로운 Vmem 값
    input  wire [REF_CTR_WIDTH-1:0]  i_ref_ctr_in, // 쓸 새로운 불응기 카운터

    // --- Read Port (to Controller, for PU input) ---
    input  wire [$clog2(NUM_NEURONS)-1:0] i_rd_addr,    // 읽을 뉴런의 주소
    output wire signed [VMEM_WIDTH-1:0] o_vmem_out,   // 읽어온 Vmem 값
    output wire [REF_CTR_WIDTH-1:0]  o_ref_ctr_out // 읽어온 불응기 카운터
);

    // --- Internal Data Packing Logic ---
    localparam STATE_WIDTH = VMEM_WIDTH + REF_CTR_WIDTH; // 총 상태 데이터 폭

    // Vivado가 이 메모리를 LUTRAM으로 합성하도록 유도하는 지시어
    (* ram_style = "distributed" *)
    reg [STATE_WIDTH-1:0] mem [0:NUM_NEURONS-1];

    wire [STATE_WIDTH-1:0] packed_wr_data;
    reg [STATE_WIDTH-1:0] packed_rd_data;

    // Packing: Vmem과 ref_ctr를 하나의 데이터 워드로 묶어 쓰기 준비
    assign packed_wr_data = {i_ref_ctr_in, i_vmem_in};

    // Unpacking: 읽어온 데이터 워드에서 Vmem과 ref_ctr를 분리
    assign o_vmem_out    = packed_rd_data[VMEM_WIDTH-1:0];
    assign o_ref_ctr_out = packed_rd_data[STATE_WIDTH-1 : VMEM_WIDTH];

    // --- Synchronous Write and Read Logic ---
    always @(posedge clk) begin
        // --- Write Operation (Port A) ---
        if (i_wr_en) begin
            mem[i_wr_addr] <= packed_wr_data;
        end

        // --- Read Operation (Port B) ---
        // LUTRAM은 보통 1 클럭의 읽기 지연 시간을 가집니다.
        // 이 코드는 주소를 입력하면 다음 클럭에 데이터가 나오는 표준적인 형태입니다.
        packed_rd_data <= mem[i_rd_addr];
    end

endmodule
