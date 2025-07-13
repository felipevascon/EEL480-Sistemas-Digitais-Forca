library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kb_code is
    generic(
        W_SIZE: integer := 2 -- 2^W_SIZE words in FIFO
    ); 
    port(
        clk: in std_logic;
        rst: in std_logic;
        ps2d: in std_logic; -- key data 
        ps2c: in std_logic; -- key clock
        rd_key_code: in std_logic;
        key_code: out std_logic_vector(7 downto 0);
        kb_buf_empty: out std_logic
    );
end kb_code;

architecture hardware of kb_code is

    component ps2_rx is
        port(
            clk: in std_logic; 
            rst: in std_logic;
            ps2d: in std_logic; 
            ps2c: in std_logic;
            rx_en: in std_logic;
            rx_done_tick: out std_logic;
            dout: out std_logic_vector(7 downto 0)
        );
    end component;

    component fifo is
        generic(
            B: natural := 8
        );
        port(
            clk: in std_logic; 
            rst: in std_logic;
            rd: in std_logic; 
            wr: in std_logic;
            w_data: in std_logic_vector(B-1 downto 0);
            empty: out std_logic; 
            full: out std_logic;
            r_data: out std_logic_vector(B-1 downto 0)
        );
    end component;

    component key2ascii is
        port(
            key_code: in std_logic_vector(7 downto 0);
            ascii_code: out std_logic_vector(7 downto 0)
        );
    end component;

    constant BRK: std_logic_vector(7 downto 0) := "11110000"; -- F0 (break code)

    -- Internal signals
    signal scan_out: std_logic_vector(7 downto 0);
    signal scan_done_tick: std_logic; 
    signal got_code_tick: std_logic;
    signal key_ascii, key_code_2: std_logic_vector(7 downto 0);

begin

    -- Instantiates the PS/2 receiver
    ps2_rx_label: ps2_rx 
        port map(
            clk => clk, 
            rst => rst, 
            rx_en => '1',
            ps2d => ps2d, 
            ps2c => ps2c,
            rx_done_tick => scan_done_tick,
            dout => scan_out
        );

    -- FIFO to store received codes
    fifo_label: fifo 
        generic map(B => 8)
        port map(
            clk => clk, 
            rst => rst, 
            rd => rd_key_code,
            wr => got_code_tick, 
            w_data => scan_out,
            empty => kb_buf_empty, 
            full => open,
            r_data => key_code_2
        );

    -- Scancode to ASCII converter
    key2ascii_label: key2ascii
        port map(
            key_code => key_code_2,
            ascii_code => key_ascii
        );

    -- Simple FSM: capture scancode if ≠ F0 (break)
    process(clk, rst)
    begin
        if rst = '1' then
            got_code_tick <= '0';
        elsif rising_edge(clk) then
            if scan_done_tick = '1' and scan_out /= BRK then
                got_code_tick <= '1';
            else
                got_code_tick <= '0';
            end if;
        end if;
    end process;

    -- Final output
    key_code <= key_ascii;
end hardware;