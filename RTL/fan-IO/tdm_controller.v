`timescale 1ns / 1ps

//==============================================================================
// --- 1. TDM Controller (FIXED: Removed unnecessary data ports) ---
//==============================================================================
module tdm_controller #(
    parameter NUM_NEURONS   = 10000,
    parameter ADDR_WIDTH    = 14
)(
    // --- Global Ports ---
    input  wire                      clk,
    input  wire                      rst_n,

    // --- Control Inputs/Outputs ---
    input  wire                      i_source_spike,
    output reg                       o_processing_done,

    // --- Neuron State Memory Interface (Control Only) ---
    output reg  [ADDR_WIDTH-1:0]     o_neuron_mem_rd_addr,
    output reg  [ADDR_WIDTH-1:0]     o_neuron_mem_wr_addr,
    output reg                       o_neuron_mem_wr_en,
    
    // --- Synapse Memory Interface (Control Only) ---
    output reg  [ADDR_WIDTH-1:0]     o_synapse_mem_rd_addr,

    // --- Neuron PU Interface (Control Only) ---
    output reg                       o_pu_in_valid,
    input  wire                      i_pu_spike_out, // Input to detect spikes

    // --- Spike Output FIFO Interface ---
    output reg                       o_spike_fifo_wr_en,
    output reg  [ADDR_WIDTH-1:0]     o_spike_fifo_wr_addr
);

    // --- FSM State Definition ---
    localparam S_IDLE = 2'b00;
    localparam S_RUN  = 2'b01;
    localparam S_DONE = 2'b10;

    reg [1:0] current_state, next_state;
    reg [ADDR_WIDTH-1:0] neuron_addr_cnt;
    
    // Pipeline registers for valid signal and write address
    reg pu_valid_pipe1, pu_valid_pipe2, pu_valid_pipe3;
    reg [ADDR_WIDTH-1:0] wr_addr_pipe1, wr_addr_pipe2, wr_addr_pipe3;


    // --- FSM Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S_IDLE;
        else        current_state <= next_state;
    end
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE: if (i_source_spike) next_state = S_RUN;
            S_RUN:  if (neuron_addr_cnt == NUM_NEURONS) next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
        endcase
    end

    // --- Main Control Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_processing_done     <= 1'b0;
            o_neuron_mem_rd_addr  <= 0;
            o_neuron_mem_wr_addr  <= 0;
            o_neuron_mem_wr_en    <= 1'b0;
            o_synapse_mem_rd_addr <= 0;
            o_pu_in_valid         <= 1'b0;
            neuron_addr_cnt       <= 0;
            o_spike_fifo_wr_en    <= 1'b0;
            pu_valid_pipe1 <= 0; pu_valid_pipe2 <= 0; pu_valid_pipe3 <= 0;
        end else begin
            // Default assignments
            o_processing_done  <= 1'b0;
            o_neuron_mem_wr_en <= 1'b0;
            o_spike_fifo_wr_en <= 1'b0;

            case (current_state)
                S_IDLE: begin
                    neuron_addr_cnt <= 0;
                    pu_valid_pipe1 <= 0; pu_valid_pipe2 <= 0; pu_valid_pipe3 <= 0;
                end

                S_RUN: begin
                    // --- Address Generation ---
                    o_neuron_mem_rd_addr  <= neuron_addr_cnt;
                    o_synapse_mem_rd_addr <= neuron_addr_cnt;
                    if (neuron_addr_cnt < NUM_NEURONS)
                        neuron_addr_cnt <= neuron_addr_cnt + 1;

                    // --- Pipeline for PU valid and Write Address ---
                    // The data read at T=0 will be valid for the PU at T=2.
                    // The result from the PU will be ready at T=3.
                    // The write-back to memory happens at T=3.
                    pu_valid_pipe1 <= 1'b1;
                    pu_valid_pipe2 <= pu_valid_pipe1;
                    pu_valid_pipe3 <= pu_valid_pipe2;
                    
                    wr_addr_pipe1 <= neuron_addr_cnt;
                    wr_addr_pipe2 <= wr_addr_pipe1;
                    wr_addr_pipe3 <= wr_addr_pipe2;

                    // --- PU Input Control ---
                    o_pu_in_valid <= pu_valid_pipe2;

                    // --- Write-back & Spike Buffering Control ---
                    if (pu_valid_pipe3) begin
                        o_neuron_mem_wr_en   <= 1'b1;
                        o_neuron_mem_wr_addr <= wr_addr_pipe3;
                        
                        if (i_pu_spike_out == 1'b1) begin
                            o_spike_fifo_wr_en   <= 1'b1;
                            o_spike_fifo_wr_addr <= wr_addr_pipe3;
                        end
                    end
                end

                S_DONE: begin
                    o_processing_done <= 1'b1;
                    neuron_addr_cnt   <= 0;
                end
            endcase
        end
    end

endmodule