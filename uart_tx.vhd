library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ_HZ : positive := 50_000_000;
        BAUD_RATE   : positive := 9600
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        tx_start  : in  std_logic;
        tx_data   : in  std_logic_vector(7 downto 0);
        uart_tx   : out std_logic;
        tx_busy   : out std_logic;
        tx_done   : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    -- Number of system clocks per UART bit
    constant CLKS_PER_BIT : positive :=
        (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
    -- UART transmitter FSM
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t := IDLE;
    -- Internal registers
    signal clk_count : natural range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_index : natural range 0 to 7 := 0;
    signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
begin
    -- UART transmitter
    process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronous reset
            if reset = '1' then
                state     <= IDLE;
                clk_count <= 0;
                bit_index <= 0;
                data_reg  <= (others => '0');
                uart_tx   <= '1';
                tx_busy   <= '0';
                tx_done   <= '0';
            else
                -- Default: tx_done is only one clock cycle
                tx_done <= '0';
                case state is
                    -- IDLE
                    when IDLE =>
                        uart_tx   <= '1';
                        tx_busy   <= '0';
                        clk_count <= 0;
                        bit_index <= 0;
                        if tx_start = '1' then
                            -- Store input byte
                            data_reg <= tx_data;
                            -- Generate start bit immediately
                            uart_tx <= '0';
                            tx_busy <= '1';
                            state <= START_BIT;
                        end if;
                    -- START BIT
                    when START_BIT =>
                        if clk_count = CLKS_PER_BIT - 1 then
                            clk_count <= 0;
                            -- First data bit: LSB
                            uart_tx <= data_reg(0);
                            state <= DATA_BITS;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                    -- DATA BITS
                    when DATA_BITS =>
                        if clk_count = CLKS_PER_BIT - 1 then
                            clk_count <= 0;
                            if bit_index = 7 then
                                -- All 8 data bits transmitted
                                bit_index <= 0;
                                -- Stop bit
                                uart_tx <= '1';
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                                -- UART sends LSB first
                                uart_tx <= data_reg(bit_index + 1);
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                    -- STOP BIT
                    when STOP_BIT =>
                        if clk_count = CLKS_PER_BIT - 1 then
                            clk_count <= 0;
                            uart_tx <= '1';
                            tx_busy <= '0';
                            tx_done <= '1';
                            state <= IDLE;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
