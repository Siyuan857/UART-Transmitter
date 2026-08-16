# UART Transmitter

## Overview

This project implements a simple and reusable UART transmitter in VHDL with a self-checking testbench.

The UART TX structure used in this project follows the same general FSM-based design methodology, while adapting the implementation into a compact **one-process FSM** with configurable clock frequency and baud rate.

The current implementation supports the standard **8N1 UART format**:

* Clock: 50 MHz by default
* Baud rate: 9600 by default
* Data: 8 bits
* Parity: None
* Stop bit: 1
* Bit order: LSB first

Parity generation is not included. If required, an additional `PARITY_BIT` state can be inserted directly into the FSM:

```text
IDLE -> START_BIT -> DATA_BITS -> PARITY_BIT -> STOP_BIT -> IDLE
```

Files:

```text
uart_tx.vhd
uart_tx_tb.vhd
```

---

## UART Transmitter

The transmitter uses four FSM states:

```text
IDLE -> START_BIT -> DATA_BITS -> STOP_BIT -> IDLE
```

### IDLE

The UART output remains HIGH.

When `tx_start = '1'`, the input byte `tx_data` is stored and transmission begins.

### START_BIT

The transmitter drives:

```text
uart_tx = '0'
```

for one UART bit period.

### DATA_BITS

Eight data bits are transmitted in LSB-first order:

```text
D0 -> D1 -> D2 -> ... -> D7
```

For example:

```text
0xA5 = 1010 0101
```

is transmitted as:

```text
Start  D0 D1 D2 D3 D4 D5 D6 D7  Stop

  0     1  0  1  0  0  1  0  1    1
```

### STOP_BIT

The UART output is driven HIGH for one bit period.

After transmission:

```text
tx_done = '1'
tx_busy = '0'
```

`tx_done` is asserted for one system-clock cycle.

---

## Timing

The number of system-clock cycles per UART bit is calculated from:

```text
CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE
```

For 50 MHz and 9600 baud:

```text
CLKS_PER_BIT ≈ 5208
UART bit period ≈ 104.17 us
```

The configuration can be changed using generics:

```vhdl
generic (
    CLK_FREQ_HZ : positive := 50_000_000;
    BAUD_RATE   : positive := 9600
);
```

---

## Interface

The main signals are:

```vhdl
tx_start : in  std_logic;
tx_data  : in  std_logic_vector(7 downto 0);

uart_tx  : out std_logic;
tx_busy  : out std_logic;
tx_done  : out std_logic;
```

### `tx_start`

Starts a new UART transmission.

It should normally be asserted for one clock cycle while:

```text
tx_busy = '0'
```

### `tx_data`

Contains the 8-bit value to transmit.

### `uart_tx`

Serial UART output.

The idle level is HIGH.

### `tx_busy`

Indicates that a UART transmission is currently in progress.

### `tx_done`

One-clock-cycle pulse indicating that a complete UART frame has been transmitted.

---

## Testbench

`uart_tx_tb.vhd` is a self-checking testbench.

It contains:

* 50 MHz clock generation
* Reset generation
* `tx_start` stimulus generation
* UART serial-output monitor
* `tx_log` for storing decoded transmitted bytes
* `tx_count` for counting transmitted frames
* Assertions for automatic error detection

The monitor decodes the serial `uart_tx` waveform back into an 8-bit value:

```text
uart_tx
   |
   v
Start + D0...D7 + Stop
   |
   v
TX Monitor
   |
   v
tx_log
```

---

## Test Cases

The testbench verifies:

### 1. Normal transmission

Transmits:

```text
0xA5
0x96
```

and checks that the UART serial waveform represents the correct bytes.

### 2. Consecutive transmissions

Transmits:

```text
0x00
0xFF
```

sequentially and verifies that both frames are generated correctly.

### 3. Busy-state behavior

A second `tx_start` request is generated while the transmitter is already busy.

The request should be ignored, and only the original byte should be transmitted.

### 4. Stop-bit verification

The testbench checks that the generated stop bit is HIGH.

---

## Vivado Simulation

Add:

```text
uart_tx.vhd
```

to **Design Sources** and:

```text
uart_tx_tb.vhd
```

to **Simulation Sources**.

Set `uart_tx_tb` as the simulation top and run:

```text
Run Behavioral Simulation
```

At 9600 baud, one complete 8N1 UART frame requires approximately:

```text
1.04 ms
```

A simulation duration of approximately:

```text
10 ms
```

is sufficient for the provided test cases.

Useful signals to observe:

```text
tx_start
tx_data
uart_tx
tx_busy
tx_done
state
clk_count
bit_index
data_reg
tx_count
```

---

## Reference

The UART transmitter design and FSM-based implementation are based on concepts presented in:

**Pong P. Chu**, *FPGA Prototyping by VHDL Examples: Xilinx Spartan-3 Version*. Wiley, 2008.

Relevant topics include:

* UART communication
* UART transmitter and receiver design
* Finite-state machine implementation
* Register-transfer level design
* Parameterized and reusable VHDL modules
* FPGA prototyping with Xilinx Spartan devices




