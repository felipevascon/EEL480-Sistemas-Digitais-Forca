library ieee;
use ieee.std_logic_1164.all;

entity fifo is
    generic(
        B: natural := 8  --number of bits per word
    );
    port(
        clk, rst : in std_logic;
        rd, wr   : in std_logic;
        w_data   : in std_logic_vector(B-1 downto 0);
        empty, full : out std_logic;
        r_data   : out std_logic_vector(B-1 downto 0)
    );
end fifo;

architecture hardware of fifo is
    signal data_reg   : std_logic_vector(B-1 downto 0) := (others => '0');
    signal full_reg   : std_logic := '0';
    signal empty_reg  : std_logic := '1';
    signal r_data_reg : std_logic_vector(B-1 downto 0) := (others => '0');
begin

    process(clk, rst)
    begin
        if rst = '1' then
            data_reg   <= (others => '0');
            r_data_reg <= (others => '0');
            full_reg   <= '0';
            empty_reg  <= '1';

        elsif rising_edge(clk) then
            -- Case of simultaneous reading and writing
            if wr = '1' and rd = '1' then
                -- Replaces the previous data with the new one immediately
                data_reg   <= w_data;
                r_data_reg <= w_data;
                full_reg   <= '1';
                empty_reg  <= '0';

            -- Writing only
            elsif wr = '1' and full_reg = '0' then
                data_reg   <= w_data;
                full_reg   <= '1';
                empty_reg  <= '0';

            -- Read only
            elsif rd = '1' and empty_reg = '0' then
                r_data_reg <= data_reg;
                full_reg   <= '0';
                empty_reg  <= '1';
            end if;
        end if;
    end process;

    -- outputs
    r_data <= r_data_reg;
    full   <= full_reg;
    empty  <= empty_reg;
end hardware;
