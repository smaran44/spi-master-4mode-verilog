`timescale 1ns / 1ps

module tb_spi_master;

// Testbench signals
reg clk;
reg rst;
reg start;
reg [7:0] tx_data;
reg CPOL;
reg CPHA;
wire mosi;
reg miso;
wire sclk;
wire cs;
wire done;
wire [7:0] rx_data;

// DUT instantiation
spi_master dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .tx_data(tx_data),
    .CPOL(CPOL),
    .CPHA(CPHA),
    .mosi(mosi),
    .miso(miso),
    .sclk(sclk),
    .cs(cs),
    .done(done),
    .rx_data(rx_data)
);

// Clock generation (100 MHz)
always #5 clk = ~clk; // 10 ns period

// SPI Slave Model - handles all 4 modes
reg [7:0] slave_data;
reg slave_preload_done;

reg [7:0] slave_rx_shift;
reg [2:0] slave_bit_cnt;

// Slave initialization on CS falling edge
always @(negedge cs) begin
    slave_data = 8'h3C;
    slave_preload_done = 1'b0;
    if (CPHA == 0) begin
        miso = slave_data[7];
        slave_preload_done = 1'b1;
      end
end

reg [7:0] slave_rx_data;

always @(posedge cs) begin
    slave_rx_data <= slave_rx_shift;
end

// Mode 0 & 3: shift on falling edge
always @(negedge sclk) begin
    if (!cs && ((CPOL == 0 && CPHA == 0) || (CPOL == 1 && CPHA == 1))) begin
        if (CPHA == 0 || slave_preload_done) begin
            slave_data <= {slave_data[6:0], 1'b0};
            miso <= slave_data[6];
        end else begin
            miso <= slave_data[7];
            slave_preload_done <= 1'b1;
        end
    end
end

// Mode 1 & 2: shift on rising edge
always @(posedge sclk) begin
    if (!cs && ((CPOL == 0 && CPHA == 1) || (CPOL == 1 && CPHA == 0))) begin
        if (CPHA == 0 || slave_preload_done) begin
            slave_data <= {slave_data[6:0], 1'b0};
            miso <= slave_data[6];
        end else begin
            miso <= slave_data[7];
            slave_preload_done <= 1'b1;
        end
    end
end

// SLAVE RX (SAMPLE MOSI)

// Modes 0 & 3 → sample on rising edge
    always @(posedge sclk) begin
        if (!cs && ((CPOL == 0 && CPHA == 0) || (CPOL == 1 && CPHA == 1))) begin
            slave_rx_shift <= {slave_rx_shift[6:0], mosi};
            slave_bit_cnt <= slave_bit_cnt + 1'b1;
        end
    end

// Modes 1 & 2 → sample on falling edge
    always @(negedge sclk) begin
        if (!cs && ((CPOL == 0 && CPHA == 1) || (CPOL == 1 && CPHA == 0))) begin
            slave_rx_shift <= {slave_rx_shift[6:0], mosi};
            slave_bit_cnt <= slave_bit_cnt + 1'b1;
        end
    end

initial begin
    clk   = 0;
    rst   = 1;
    start = 0;
    tx_data = 8'hA5;
    miso = 0;
    
    #50 rst = 0;
    
    // MODE 0 (CPOL=0, CPHA=0)
    #20;
    CPOL = 0; CPHA = 0;
    $display("\n=== MODE 0: CPOL=%b, CPHA=%b ===", CPOL, CPHA);
    run_and_check();
    
    // MODE 1 (CPOL=0, CPHA=1)
    #50;  // Add delay between modes
    CPOL = 0; CPHA = 1;
    $display("\n=== MODE 1: CPOL=%b, CPHA=%b ===", CPOL, CPHA);
    run_and_check();
    
    // MODE 2 (CPOL=1, CPHA=0)
    #50;
    CPOL = 1; CPHA = 0;
    $display("\n=== MODE 2: CPOL=%b, CPHA=%b ===", CPOL, CPHA);
    run_and_check();
    
    // MODE 3 (CPOL=1, CPHA=1)
    #50;
    CPOL = 1; CPHA = 1;
    $display("\n=== MODE 3: CPOL=%b, CPHA=%b ===", CPOL, CPHA);
    run_and_check();
    
    #100 $finish; 
end
    
task run_and_check;
    reg [7:0] master_rx;
    reg [7:0] slave_rx;
    begin
        // RESET SLAVE SIDE STATE
        slave_rx_shift = 8'd0;
        slave_bit_cnt  = 3'd0;

        // START TRANSACTION 
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // WAIT FOR CS ASSERT
        wait (cs == 1'b0);

        // WAIT FOR CS DEASSERT (transaction truly finished)
        wait (cs == 1'b1);

        @(posedge clk);

        master_rx = rx_data;
        slave_rx  = slave_rx_data;

        $display("TX (Master->Slave): %h | RX at Slave: %h",
                 tx_data, slave_rx);
        $display("TX (Slave->Master): %h | RX at Master: %h",
                 8'h3C, master_rx);

        if (master_rx === 8'h3C && slave_rx === tx_data) begin
            $display("RESULT: PASS");
        end
        else begin
            $display("RESULT: FAIL");
            if (master_rx !== 8'h3C)
                $display("  ERROR: Master RX mismatch");
            if (slave_rx !== tx_data)
                $display("  ERROR: Slave RX mismatch");
        end

        repeat (5) @(posedge clk);
    end
endtask

endmodule
