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
    parameter NUM_NEURONS   = 128,    // ������ �� �ҽ� ������ ����
    parameter VMEM_WIDTH    = 16,     // ������(Vmem)�� ��Ʈ ��
    parameter REF_CTR_WIDTH = 4       // ������ ī������ ��Ʈ ��
)(
    // --- Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Write Port (from Controller, with data from PU) ---
    input  wire                      i_wr_en,      // ���� Ȱ��ȭ
    input  wire [$clog2(NUM_NEURONS)-1:0] i_wr_addr,    // �� ������ �ּ�
    input  wire signed [VMEM_WIDTH-1:0] i_vmem_in,    // �� ���ο� Vmem ��
    input  wire [REF_CTR_WIDTH-1:0]  i_ref_ctr_in, // �� ���ο� ������ ī����

    // --- Read Port (to Controller, for PU input) ---
    input  wire [$clog2(NUM_NEURONS)-1:0] i_rd_addr,    // ���� ������ �ּ�
    output wire signed [VMEM_WIDTH-1:0] o_vmem_out,   // �о�� Vmem ��
    output wire [REF_CTR_WIDTH-1:0]  o_ref_ctr_out // �о�� ������ ī����
);

    // --- Internal Data Packing Logic ---
    localparam STATE_WIDTH = VMEM_WIDTH + REF_CTR_WIDTH; // �� ���� ������ ��

    // Vivado�� �� �޸𸮸� LUTRAM���� �ռ��ϵ��� �����ϴ� ���þ�
    (* ram_style = "distributed" *)
    reg [STATE_WIDTH-1:0] mem [0:NUM_NEURONS-1];

    wire [STATE_WIDTH-1:0] packed_wr_data;
    reg [STATE_WIDTH-1:0] packed_rd_data;

    // Packing: Vmem�� ref_ctr�� �ϳ��� ������ ����� ���� ���� �غ�
    assign packed_wr_data = {i_ref_ctr_in, i_vmem_in};

    // Unpacking: �о�� ������ ���忡�� Vmem�� ref_ctr�� �и�
    assign o_vmem_out    = packed_rd_data[VMEM_WIDTH-1:0];
    assign o_ref_ctr_out = packed_rd_data[STATE_WIDTH-1 : VMEM_WIDTH];

    // --- Synchronous Write and Read Logic ---
    always @(posedge clk) begin
        // --- Write Operation (Port A) ---
        if (i_wr_en) begin
            mem[i_wr_addr] <= packed_wr_data;
        end

        // --- Read Operation (Port B) ---
        // LUTRAM�� ���� 1 Ŭ���� �б� ���� �ð��� �����ϴ�.
        // �� �ڵ�� �ּҸ� �Է��ϸ� ���� Ŭ���� �����Ͱ� ������ ǥ������ �����Դϴ�.
        packed_rd_data <= mem[i_rd_addr];
    end

endmodule
