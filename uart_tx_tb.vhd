library ieee;
use ieee.std_logic_1164.all;

entity uart_tx_tb is
end entity uart_tx_tb;

architecture sim of uart_tx_tb is
    ------------------------------------------------------------
    -- Configuration
    ------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns;       -- 50 MHz
    constant BIT_PERIOD : time := 104_166 ns;   -- 9600 baud
    ------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal tx_start  : std_logic := '0';
    signal tx_data   : std_logic_vector(7 downto 0) := (others => '0');                    
    signal uart_tx   : std_logic;
    signal tx_busy   : std_logic;
    signal tx_done   : std_logic;
    ------------------------------------------------------------
    -- Scoreboard
    ------------------------------------------------------------
    type byte_array_t is
        array (0 to 15) of std_logic_vector(7 downto 0);
    signal tx_log :
        byte_array_t := (others => (others => '0'));
    signal tx_count :
        natural range 0 to 15 := 0;
    ------------------------------------------------------------
    -- Start one UART transmission
    ------------------------------------------------------------
    procedure start_tx (
        signal clk_s   : in  std_logic;
        signal start_s : out std_logic;
        signal data_s  : out std_logic_vector(7 downto 0);
        constant data  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        --------------------------------------------------------
        -- Apply signals before rising clock edge
        --------------------------------------------------------
        wait until falling_edge(clk_s);
        data_s  <= data;
        start_s <= '1';
        --------------------------------------------------------
        -- DUT samples tx_start here
        --------------------------------------------------------
        wait until rising_edge(clk_s);
        wait for 1 ns;
        start_s <= '0';
    end procedure;
begin
    ------------------------------------------------------------
    -- 50 MHz clock
    ------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;
    ------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------
    DUT : entity work.uart_tx
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            BAUD_RATE   => 9600
        )
        port map (
            clk      => clk,
            reset    => reset,
            tx_start => tx_start,
            tx_data  => tx_data,
            uart_tx  => uart_tx,
            tx_busy  => tx_busy,
            tx_done  => tx_done
        );
    ------------------------------------------------------------
    -- UART output monitor
    -- Decodes the serial TX output back into bytes.
    ------------------------------------------------------------
    monitor_process : process
        variable data_v :
            std_logic_vector(7 downto 0);
    begin
        loop
            ----------------------------------------------------
            -- Detect start bit
            ----------------------------------------------------
            wait until falling_edge(uart_tx);
            ----------------------------------------------------
            -- Move to center of D0
            --
            -- 1 bit   : end of start bit
            -- 0.5 bit : center of D0
            ----------------------------------------------------
            wait for BIT_PERIOD + BIT_PERIOD / 2;
            ----------------------------------------------------
            -- Sample D0 ... D7
            ----------------------------------------------------
            for i in 0 to 7 loop
                data_v(i) := uart_tx;
                wait for BIT_PERIOD;
            end loop;
            ----------------------------------------------------
            -- We are now approximately at center of stop bit
            ----------------------------------------------------
            assert uart_tx = '1'
                report
                "ERROR: Invalid UART stop bit generated."
                severity error;
            ----------------------------------------------------
            -- Store transmitted byte
            ----------------------------------------------------
            tx_log(tx_count) <= data_v;
            tx_count <= tx_count + 1;
        end loop;
    end process;
    ------------------------------------------------------------
    -- Main test process
    ------------------------------------------------------------
    stimulus_process : process
        variable count_before : natural;
    begin
        --------------------------------------------------------
        -- Reset
        --------------------------------------------------------
        reset <= '1';
        tx_start <= '0';
        tx_data  <= (others => '0');
        wait for 100 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 100 ns;
        --------------------------------------------------------
        -- Check idle state
        --------------------------------------------------------
        assert uart_tx = '1'
            report
            "ERROR: UART TX should be HIGH in IDLE."
            severity error;

        assert tx_busy = '0'
            report
            "ERROR: tx_busy should be LOW after reset."
            severity error;
        --------------------------------------------------------
        -- TEST 1
        -- Transmit A5
        --------------------------------------------------------
        report "TEST 1: Transmit A5"
            severity note;
        count_before := tx_count;
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"A5"
        );
        wait until tx_done = '1';

        wait for 100 ns;
        assert tx_count = count_before + 1
            report
            "TEST 1 ERROR: Expected one UART frame."
            severity error;
        assert tx_log(count_before) = x"A5"
            report
            "TEST 1 ERROR: UART output is not A5."
            severity error;
        report "TEST 1 PASSED"
            severity note;
        --------------------------------------------------------
        -- TEST 2
        -- Transmit 96
        --------------------------------------------------------
        report "TEST 2: Transmit 96"
            severity note;
        count_before := tx_count;
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"96"
        );
        wait until tx_done = '1';
        wait for 100 ns;
        assert tx_count = count_before + 1
            report
            "TEST 2 ERROR: Expected one UART frame."
            severity error;
        assert tx_log(count_before) = x"96"
            report
            "TEST 2 ERROR: UART output is not 96."
            severity error;
        report "TEST 2 PASSED"
            severity note;
        --------------------------------------------------------
        -- TEST 3
        -- Consecutive transmissions
        --------------------------------------------------------
        report "TEST 3: Consecutive 00 and FF"
            severity note;
        count_before := tx_count;
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"00"
        );
        wait until tx_done = '1';
        --------------------------------------------------------
        -- Start next frame as soon as transmitter is available
        --------------------------------------------------------
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"FF"
        );
        wait until tx_done = '1';
        wait for 100 ns;
        assert tx_count = count_before + 2
            report
            "TEST 3 ERROR: Expected two UART frames."
            severity error;
        assert tx_log(count_before) = x"00"
            report
            "TEST 3 ERROR: First frame should be 00."
            severity error;
        assert tx_log(count_before + 1) = x"FF"
            report
            "TEST 3 ERROR: Second frame should be FF."
            severity error;
        report "TEST 3 PASSED"
            severity note;
        --------------------------------------------------------
        -- TEST 4
        -- tx_start while transmitter is busy
        --------------------------------------------------------
        report "TEST 4: Ignore tx_start while busy"
            severity note;
        count_before := tx_count;
        --------------------------------------------------------
        -- Start valid transmission
        --------------------------------------------------------
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"3C"
        );
        --------------------------------------------------------
        -- Wait until transmission is already running
        --------------------------------------------------------
        wait for 2 * BIT_PERIOD;
        assert tx_busy = '1'
            report
            "TEST 4 ERROR: tx_busy should be HIGH."
            severity error;
        --------------------------------------------------------
        -- Try to start another byte while busy.
        -- This request should be ignored.
        --------------------------------------------------------
        start_tx(
            clk,
            tx_start,
            tx_data,
            x"F0"
        );
        wait until tx_done = '1';
        wait for 100 ns;
        --------------------------------------------------------
        -- Only 3C should have been transmitted
        --------------------------------------------------------
        assert tx_count = count_before + 1
            report
            "TEST 4 ERROR: tx_start was incorrectly accepted while busy."
            severity error;

        assert tx_log(count_before) = x"3C"
            report
            "TEST 4 ERROR: Transmitted byte should be 3C."
            severity error;
        report "TEST 4 PASSED"
            severity note;
        --------------------------------------------------------
        -- All tests completed
        --------------------------------------------------------
        report "----------------------------------------"
            severity note;
        report "ALL UART TX TESTS PASSED"
            severity note;
        report "----------------------------------------"
            severity note;
        wait;
    end process;
end architecture sim;