`timescale 1ns / 1ps
module neuron_body #(
    parameter DW = 8,
    parameter ACCW = 8,
    parameter RELREF_DUR = 8,
    parameter ABSREF_DUR = 16
)(
    input wire clk,
    input wire rst_n,

    // --- Inputs: ���������� ����ġ�� ���� ��ȣ�� ���� ---
    input wire signed [DW-1:0] weight_in,
    input wire weight_valid_in,
    input wire weight_last_in, // ���� ����ġ�� �̹� Ÿ�ӽ����� ���������� ǥ��

    // --- Outputs ---
    output reg spike_out,
    output reg signed [ACCW-1:0] vmem
);

    // FSM ���� ����
    localparam S_IDLE      = 3'b000;
    localparam S_ACCUM     = 3'b001; // ����ġ ���� ����
    localparam S_INTEGRATE = 3'b010; // ������ ��� ����
    localparam S_FIRE      = 3'b011;
    localparam S_RELREF    = 3'b100;
    localparam S_ABSREF    = 3'b101;

    reg [2:0] state, next_state;
    
    // ���� �Ķ���� (Q4.4 ����)
    localparam signed [ACCW-1:0] VMEM_INIT = -16; // -1.0
    localparam signed [ACCW-1:0] VTH       = 8;   // 0.5
    localparam signed [ACCW-1:0] OVERSHOOT = 0;
    localparam signed [ACCW-1:0] LEAK      = 1;   // 0.0625

    // ���� ��������
    reg signed [ACCW+7:0] mac_reg; // ����ġ ������
    reg [7:0] ref_cnt;             // ������ Ÿ�̸�
    
    // [���� ����] wire -> reg�� ����
    reg signed [ACCW-1:0] vmem_next;

    // --- ���� ����(next_state) �� ���� ������(vmem_next) ����� ���� ���� �� ---
    always @(*) begin
        next_state = state;
        vmem_next = vmem;
        spike_out = 1'b0;

        case (state)
            S_IDLE: begin
                if (weight_valid_in) begin
                    next_state = S_ACCUM;
                end
            end
            S_ACCUM: begin
                if (weight_last_in && weight_valid_in) begin
                    next_state = S_INTEGRATE;
                end
            end
            S_INTEGRATE: begin
                // vmem_next�� ���� vmem�� ������ mac_reg�� ������� ���
                vmem_next = vmem + mac_reg - LEAK;
                if (vmem_next >= VTH) begin
                    next_state = S_FIRE;
                end else begin
                    next_state = S_IDLE;
                end
            end
            S_FIRE: begin
                spike_out = 1'b1;
                // vmem ���� ���� ������ ���� ����
                if (vmem >= OVERSHOOT) begin
                    next_state = S_ABSREF;
                end else begin
                    next_state = S_RELREF;
                end
            end
            S_RELREF: begin
                vmem_next = vmem - (LEAK + 1); // �� ���� ����
                if (ref_cnt == 1) next_state = S_IDLE;
            end
            S_ABSREF: begin
                vmem_next = vmem - (LEAK + 2); // ���� ���� ����
                if (ref_cnt == 1) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end
    
    // --- FSM�� �������� ������Ʈ�� ���� ���� �� ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            vmem    <= VMEM_INIT;
            mac_reg <= 0;
            ref_cnt <= 0;
        end else begin
            state <= next_state;

            // vmem ������Ʈ
            // S_INTEGRATE, S_RELREF, S_ABSREF ���¿��� vmem_next ������ ������Ʈ
            if (next_state == S_INTEGRATE || next_state == S_RELREF || next_state == S_ABSREF) begin
                vmem <= vmem_next;
            end
            
            // mac_reg ������Ʈ
            if (state == S_IDLE && next_state == S_ACCUM) begin
                 mac_reg <= $signed(weight_in); // ���� ����
            end else if (state == S_ACCUM) begin
                 if(weight_valid_in) mac_reg <= mac_reg + $signed(weight_in);
            end else if (state == S_INTEGRATE) begin
                mac_reg <= 0; // ������ �ʱ�ȭ
            end

            // ref_cnt ������Ʈ
            if (next_state == S_RELREF) begin
                if(state != S_RELREF) ref_cnt <= RELREF_DUR;
                else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1;
            end else if (next_state == S_ABSREF) begin
                if(state != S_ABSREF) ref_cnt <= ABSREF_DUR;
                else if (ref_cnt > 0) ref_cnt <= ref_cnt - 1;
            end else begin
                ref_cnt <= 0;
            end

            // ������ ���� �� vmem ����
            if(ref_cnt == 1) vmem <= VMEM_INIT; 
        end
    end

endmodule