`timescale 1ns / 1ps

module neuron_body #(
    parameter DATA_WIDTH = 8,
    parameter THRESH = 15,
    parameter THRESH_HIGH = 40,
    parameter OVERSHOOT = 70,
    parameter MAX_VAL = 100,
    parameter LEAK_IDLE = 2,
    parameter LEAK_REF = 20
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
    reg [DATA_WIDTH:0] tmp_sum;
    reg [DATA_WIDTH-1:0] vmem_prev;

    // next_state 논리
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (vmem >= THRESH)
                    next_state = S_SPIKE;
            end
            S_SPIKE: begin
                next_state = S_ABS_REF;
            end
            S_ABS_REF: begin
                if (vmem <= 70)
                    next_state = S_REL_REF;
            end
            S_REL_REF: begin
                if (vmem == 0)
                    next_state = S_IDLE;
                else if ((vmem >= THRESH_HIGH) && in_valid)
                    next_state = S_SPIKE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // FSM 및 내부 동작 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            vmem      <= 0;
            vmem_prev <= 0;
            out_spike <= 1'b0;
        end else begin
            state     <= next_state;
            vmem_prev <= vmem;
            out_spike <= 1'b0; // 매 사이클 기본값은 0
    
            case (state)
                S_IDLE: begin
                    // 1. bình thường vmem 업데이트 (입력/누수)
                    if (in_valid) begin
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
                    // 2. 스파이크 발생 조건을 만족하면 vmem을 MAX_VAL로 덮어쓰기
                    //    (이 로직은 1번 로직 다음에 위치하여 vmem 값을 최종 결정합니다)
                    if ((vmem_prev < THRESH) && (vmem >= THRESH)) begin
                        vmem <= MAX_VAL;
                    end
                end
                
                S_SPIKE: begin
                    out_spike <= 1'b1;
                    vmem <= MAX_VAL;
                end
    
                S_ABS_REF: begin
                    // LEAK_REF만큼 누수만 적용
                    if (vmem > LEAK_REF)
                        vmem <= vmem - LEAK_REF;
                    else
                        vmem <= 0;
                end
                S_REL_REF: begin
                    if (in_valid) begin
                        tmp_sum = vmem + in_mac_sum;
                        if (tmp_sum > LEAK_REF) begin // S_REL_REF에서는 LEAK_REF 사용
                            tmp_sum = tmp_sum - LEAK_REF;
                            if (tmp_sum >= MAX_VAL)
                                vmem <= MAX_VAL;
                            else
                                vmem <= tmp_sum[DATA_WIDTH-1:0];
                        end else begin
                            vmem <= 0;
                        end
                    end else begin
                        if (vmem > LEAK_REF)
                            vmem <= vmem - LEAK_REF;
                        else
                            vmem <= 0;
                    end
                    // 2. 재발화 조건을 만족하면 vmem을 MAX_VAL로 덮어쓰기
                    if ((vmem_prev < THRESH_HIGH) && (vmem >= THRESH_HIGH)) begin
                        vmem <= MAX_VAL;
                    end
                end
                default: begin
                    vmem      <= 0;
                    vmem_prev <= 0;
                    out_spike <= 1'b0;
                end
            endcase
        end
    end


    always @(*) begin
        out_vmem = vmem;
    end

endmodule

