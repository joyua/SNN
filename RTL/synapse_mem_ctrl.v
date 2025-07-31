`timescale 1ns / 1ps

`timescale 1ns / 1ps

// Module: synapse_mem_ctrl
// Function: Controls the synapse memory access based on input spike events.
//           Fetches weights only for active synapses in a sequential manner.
module synapse_mem_ctrl #(
    parameter DATA_WIDTH  = 8,
    parameter ADDR_WIDTH  = 14,
    parameter FIFO_DW     = 14 // ������ũ �ּ� FIFO�� ������ ��
)(
    // Global & Control Signals
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        i_start_fetch,

    // Input Spike Address FIFO Interface
    input   wire [FIFO_DW-1:0]          i_spike_addr_fifo_data,
    input   wire                        i_spike_addr_fifo_valid,
    output  reg                         o_spike_addr_fifo_rden,

    // Synapse Memory Interface
    input   wire [DATA_WIDTH-1:0]       i_syn_mem_rdata,
    output  reg  [ADDR_WIDTH-1:0]       o_syn_mem_addr,

    // Output to MAC Unit
    output  reg                         o_weight_valid,
    output  reg  [DATA_WIDTH-1:0]       o_weight_data,
    
    // Status Output
    output  reg                         o_fetch_done
);

    // FSM ���� ����
    localparam S_IDLE        = 3'd0;
    localparam S_READ_FIFO   = 3'd1;
    localparam S_WAIT_MEM    = 3'd2;
    localparam S_OUTPUT      = 3'd3;
    localparam S_DONE        = 3'd4;

    // ���� �������� ����
    reg [2:0] current_state, next_state;

    // FSM ���� ���� ���� (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM ���� ���� ���� ���� (Combinational)
    always @(*) begin
        next_state = current_state; // �⺻������ ���� ���� ����
        case (current_state)
            S_IDLE: begin
                if (i_start_fetch && i_spike_addr_fifo_valid) begin
                    next_state = S_READ_FIFO;
                end
            end
            S_READ_FIFO: begin
                next_state = S_WAIT_MEM;
            end
            S_WAIT_MEM: begin
                next_state = S_OUTPUT;
            end
            S_OUTPUT: begin
                if (i_spike_addr_fifo_valid) begin
                    next_state = S_READ_FIFO; // ó���� �ּҰ� �� ������ �ٽ� FIFO �б�
                end else begin
                    next_state = S_DONE;      // ������ �Ϸ�
                end
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // ��� �� ���� ���� ���� (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_spike_addr_fifo_rden <= 1'b0;
            o_syn_mem_addr         <= {ADDR_WIDTH{1'b0}};
            o_weight_valid         <= 1'b0;
            o_weight_data          <= {DATA_WIDTH{1'b0}};
            o_fetch_done           <= 1'b0;
        end else begin
            // ��� ��� ��ȣ�� �� ����Ŭ�� ��ȿ�ϵ��� �⺻���� 0���� ����
            o_spike_addr_fifo_rden <= 1'b0;
            o_weight_valid         <= 1'b0;
            o_fetch_done           <= 1'b0;

            case (current_state)
                S_READ_FIFO: begin
                    // FIFO���� �ּҸ� �а�, �� �ּҸ� Synapse Memory�� ����
                    o_spike_addr_fifo_rden <= 1'b1;
                    o_syn_mem_addr         <= i_spike_addr_fifo_data;
                end
                S_OUTPUT: begin
                    // Memory���� �� �����͸� ���� ����ġ�� ���
                    o_weight_valid <= 1'b1;
                    o_weight_data  <= i_syn_mem_rdata;
                end
                S_DONE: begin
                    // ��� ����ġ fetch�� �������� �˸�
                    o_fetch_done <= 1'b1;
                end
            endcase
        end
    end

endmodule