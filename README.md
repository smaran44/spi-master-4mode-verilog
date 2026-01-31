# 4-Mode SPI Master in Verilog

Fully functional SPI Master controller supporting all four SPI modes (CPOL/CPHA combinations), designed and verified in Verilog using Vivado simulator.

## Features

- Supports SPI Modes 0, 1, 2, 3
- FSM-based control architecture
- CPOL / CPHA configurable
- Internal SCLK divider
- Bidirectional MOSI/MISO transfer
- Self-checking testbench
- Waveform-verified timing
- RTL and synthesis schematics included

## Folder Structure

rtl/ → SPI master RTL  
tb/ → Testbench  
sim/ → Simulation outputs & waveforms  
schematics/ → RTL & synthesis schematics  
docs/ → Detailed PDF report  

## Tools Used

- Verilog HDL
- Xilinx Vivado Simulator

## Verification

All four SPI modes simulated and verified using behavioral slave model.  
Both transmit and receive paths validated.

## Author

Smaran Yanapu
