`timescale 1ns / 1ps

module spi_master (
    input  wire        clk,        // system clock
    input  wire        rst,        // synchronous reset
    input  wire        start,      // start transaction
    input  wire [7:0]  tx_data,    // data to send
    input wire        CPOL,        // clock idle polarity
    input wire        CPHA,        // clock phase

    output reg         mosi,
    input  wire        miso,
    output reg         sclk,
    output reg         cs,
    output reg         done,
    output reg [7:0]   rx_data
);

// FSM state encoding
    parameter IDLE       = 3'd0;
    parameter LOAD       = 3'd1;
    parameter ASSERT_CS  = 3'd2;
    parameter TRANSFER   = 3'd3;
    parameter DONE_STATE = 3'd4;

reg [2:0] state, next_state;

// Shift registers and bit counter
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_cnt;

// sclk generation
reg sclk_en;
reg [1:0] clk_div_cnt;  // counts 0 to 3
always @(posedge clk) begin
    if (rst || !sclk_en) begin
        sclk <= CPOL;
        clk_div_cnt <= 2'd0;
    end else begin
        if (clk_div_cnt == 2'd3) begin
            clk_div_cnt <= 2'd0;
            sclk <= ~sclk;
        end else begin
            clk_div_cnt <= clk_div_cnt + 1;
        end
    end
end

// detect sclk edges
reg sclk_prev;
always @(posedge clk) begin
    if (rst)
          sclk_prev <= CPOL;
    else
        sclk_prev <= sclk;
end

wire sclk_rising;
wire sclk_falling;

assign sclk_rising  = (sclk_prev == 1'b0 && sclk == 1'b1);
assign sclk_falling = (sclk_prev == 1'b1 && sclk == 1'b0);

wire shift_edge;
wire sample_edge;

assign shift_edge  =
    (CPOL == 0 && CPHA == 0) ? sclk_falling :
    (CPOL == 0 && CPHA == 1) ? sclk_rising  :
    (CPOL == 1 && CPHA == 0) ? sclk_rising  :
                              sclk_falling ;

assign sample_edge =
    (CPOL == 0 && CPHA == 0) ? sclk_rising  :
    (CPOL == 0 && CPHA == 1) ? sclk_falling :
    (CPOL == 1 && CPHA == 0) ? sclk_falling :
                              sclk_rising  ;
                              
// FSM: state register
always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

// FSM: next-state logic
always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                next_state = ASSERT_CS;
            end

            ASSERT_CS: begin
                next_state = TRANSFER;
            end

            TRANSFER: begin
                if (sample_edge && bit_cnt == 3'd7)
                    next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end
    
reg preload_done;
    
// FSM: output and datapath logic
always @(posedge clk) begin
        if (rst) begin
            cs       <= 1'b1;
            done     <= 1'b0;
            sclk_en  <= 1'b0;
            bit_cnt  <= 3'd0;
            tx_shift <= 8'd0;
            rx_shift <= 8'd0;
            rx_data  <= 8'd0;
            mosi     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    cs      <= 1'b1;
                    sclk_en <= 1'b0;
                    bit_cnt <= 3'd0;
                end

                LOAD: begin
                    tx_shift <= tx_data;   // latch TX data once
                end

                ASSERT_CS: begin
                    cs      <= 1'b0;
                    sclk_en <= 1'b1;
                    preload_done <= 1'b0;
                    
                    if (CPHA == 0) begin
                        mosi    <= tx_shift[7];
                        preload_done <= 1'b1;
                    end
                end

                TRANSFER: begin

                    // SHIFT (TX)
                    if (shift_edge) begin
                        if (CPHA == 0 || preload_done) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi     <= tx_shift[6];
                        end else begin
                            // First shift edge in CPHA=1: preload instead
                            mosi <= tx_shift[7];
                            preload_done <= 1'b1;
                        end
                    end

                    // SAMPLE (RX)
                    if (sample_edge) begin
                        if (preload_done) begin
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt  <= bit_cnt + 1'b1;
                        end
                    end
                end

                DONE_STATE: begin
                    sclk_en <= 1'b0;
                    cs      <= 1'b1;
                    rx_data <= rx_shift;
                    done    <= 1'b1;
                end

            endcase
        end
    end

endmodule
    
