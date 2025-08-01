`timescale 1ns / 1ps

module tb_synapse_memory;

    // DUT 파라미터 정의
    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 10000;
    localparam ADDR_WIDTH = 14;

    // 테스트벤치 신호 선언
    reg                      clk;
    reg                      rst_n;
    reg  [ADDR_WIDTH-1:0]    i_read_addr;
    wire [DATA_WIDTH-1:0]    o_read_weight;
    reg                      i_write_en;
    reg  [ADDR_WIDTH-1:0]    i_write_addr;
    reg  [DATA_WIDTH-1:0]    i_write_data;
    
    // DUT (Device Under Test) 인스턴스화
    synapse_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_read_addr(i_read_addr),
        .o_read_weight(o_read_weight),
        .i_write_en(i_write_en),
        .i_write_addr(i_write_addr),
        .i_write_data(i_write_data)
    );

    // 1. 클럭 생성
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 주기 (100MHz)
    end

    // 2. 테스트 시나리오
    initial begin
        $display("===================================================");
        $display("             Synapse Memory Test Start             ");
        $display("===================================================");
        
        // --- 시나리오 1: 초기화 및 읽기 테스트 ---
        $display("\n--- [Scenario 1] Reset & Read Initial Data ---");
        rst_n = 1'b0;
        i_read_addr = 0;
        i_write_en = 0;
        i_write_addr = 0;
        i_write_data = 0;
        #20;
        rst_n = 1'b1;
        #10;

        $display("Reading from address 0x0000...");
        i_read_addr = 14'h0000;
        #10; // 1 클럭 대기
        if (o_read_weight === 8'h11) $display("SUCCESS: Read 0x%h", o_read_weight);
        else $display("FAILURE: Expected 0x11, Read 0x%h", o_read_weight);

        $display("Reading from address 0x000A...");
        i_read_addr = 14'h000A;
        #10; // 1 클럭 대기
        if (o_read_weight === 8'hAA) $display("SUCCESS: Read 0x%h", o_read_weight);
        else $display("FAILURE: Expected 0xAA, Read 0x%h", o_read_weight);
        #10;

        // --- 시나리오 2: 쓰기 및 확인 테스트 ---
        $display("\n--- [Scenario 2] Write & Verify Test ---");
        $display("Writing 0xEE to address 0x0100...");
        i_write_en = 1'b1;
        i_write_addr = 14'h0100;
        i_write_data = 8'hEE;
        #10; // 1 클럭 동안 쓰기 활성화
        i_write_en = 1'b0; // 쓰기 비활성화
        
        $display("Verifying write operation by reading from 0x0100...");
        i_read_addr = 14'h0100;
        #10; // 1 클럭 대기
        if (o_read_weight === 8'hEE) $display("SUCCESS: Read 0x%h", o_read_weight);
        else $display("FAILURE: Expected 0xEE, Read 0x%h", o_read_weight);
        #10;

        // --- 시나리오 3: 동시 읽기/쓰기 테스트 ---
        $display("\n--- [Scenario 3] Simultaneous Read/Write Test ---");
        $display("Simultaneously reading and writing to address 0x0002 (Initial value: 0x33, New value: 0xFF)");
        i_read_addr = 14'h0002;
        i_write_en = 1'b1;
        i_write_addr = 14'h0002;
        i_write_data = 8'hFF;
        #10; // 1 클럭 동안 동시 동작
        
        $display("Checking read output (should be old data)...");
        if (o_read_weight === 8'h33) $display("SUCCESS: Read old value 0x%h as expected.", o_read_weight);
        else $display("FAILURE: Expected old value 0x33, Read 0x%h", o_read_weight);
        
        i_write_en = 1'b0; // 쓰기 비활성화
        i_read_addr = 14'h0002; // 같은 주소 다시 읽기
        
        #10; // 1 클럭 대기
        $display("Checking read output again (should be new data)...");
        if (o_read_weight === 8'hFF) $display("SUCCESS: Read new value 0x%h as expected.", o_read_weight);
        else $display("FAILURE: Expected new value 0xFF, Read 0x%h", o_read_weight);
        #10;

        // --- 테스트 종료 ---
        $display("\n===================================================");
        $display("              Synapse Memory Test End              ");
        $display("===================================================");
        $finish;
    end

endmodule
