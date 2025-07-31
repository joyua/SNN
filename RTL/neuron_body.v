`timescale 1ns / 1ps

module neuron_body #(
    parameter DATA_WIDTH = 8,
    parameter THRESH = 15,
    parameter THRESH_HIGH = 40,
    parameter OVERSHOOT = 70,
    parameter MAX_VAL = 100,
    parameter LEAK_IDLE = 2,
    parameter LEAK_REF = 40
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   in_valid,
    input  wire [DATA_WIDTH-1:0]  in_mac_sum,
    output reg                    out_spike,
    output reg [DATA_WIDTH-1:0]   out_vmem
);

    localparam S_IDLE    = 2'd0;
    localparam S_SPIKE   = 2'd1;
    localparam S_REL_REF = 2'd2;
    localparam S_ABS_REF = 2'd3;

    reg [1:0] state, next_state;
    reg [DATA_WIDTH-1:0] vmem;
    reg [DATA_WIDTH-1:0] pre_spike_vmem; // spike 전 막전위 값
    reg [DATA_WIDTH:0] tmp_sum;

    // next_state 논리
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (vmem >= THRESH)
                    next_state = S_SPIKE;
            end
            S_SPIKE: begin
                // spike 직전 값 기준 분기
                if (pre_spike_vmem >= OVERSHOOT)
                    next_state = S_ABS_REF;
                else
                    next_state = S_REL_REF;
            end
            S_REL_REF: begin
                if (vmem == 0)
                    next_state = S_IDLE;
                else if (vmem >= THRESH_HIGH)
                    next_state = S_SPIKE;
            end
            S_ABS_REF: begin
                if (vmem == 0)
                    next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // FSM 및 내부 동작
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            vmem           <= 0;
            pre_spike_vmem <= 0;
            out_spike     <= 1'b0;
        end else begin
            state     <= next_state;
            out_spike <= 1'b0;
    
            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                    // 입력이 있을 때: 누수와 누적을 함께 처리
                    // (언더플로우 방지: vmem + in_mac_sum이 LEAK_IDLE보다 작으면 0으로 처리)
                    tmp_sum = vmem + in_mac_sum;
                    if (tmp_sum > LEAK_IDLE) begin
                        tmp_sum = tmp_sum - LEAK_IDLE;
                        if (tmp_sum >= MAX_VAL)
                            vmem <= MAX_VAL;
                        else
                            vmem <= tmp_sum[DATA_WIDTH-1:0];
                    end else begin
                        vmem <= 0;
                    end
                end else begin
                    if (vmem > LEAK_IDLE)
                        vmem <= vmem - LEAK_IDLE;
                    else
                        vmem <= 0;
                 end
                    // spike 조건에서만 pre_spike_mem 저장
                    if ((vmem < THRESH) && (vmem + in_mac_sum >= THRESH))
                        pre_spike_vmem <= vmem + in_mac_sum;
                end
                S_SPIKE: begin
                    out_spike <= 1'b1;
                    // mem을 변화시키지 않음! (overshoot 값 유지)
                end
                S_REL_REF: begin
                    // leak 적용 (입력/누적 허용 시 여기서 처리)
                    if (vmem > LEAK_REF)
                        vmem <= vmem - LEAK_REF;
                    else
                        vmem <= 0;
                    // 입력 누적 허용 시, 여기에 추가
                    // if (in_valid) mem <= mem + in_mac_sum;
                end
                S_ABS_REF: begin
                    // leak만 적용
                    if (vmem > LEAK_REF)
                        vmem <= vmem - LEAK_REF;
                    else
                        vmem <= 0;
                end
                default: begin
                    vmem         <= 0;
                    pre_spike_vmem <= 0;
                    out_spike   <= 1'b0;
                end
            endcase
        end
    end


    always @(*) begin
        out_vmem = vmem;
    end

endmodule

