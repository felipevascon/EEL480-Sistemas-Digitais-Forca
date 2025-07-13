library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd is
    port(
        LCD_DB: out std_logic_vector(7 downto 0); --DB( 7 through 0)
        RS:out std_logic; --WE
        RW:out std_logic; --ADR(0)
        CLK:in std_logic; --GCLK2
        OE:out std_logic; --OE
        rst:in std_logic; --BTN
        ps2d: in std_logic; 
        ps2c: in std_logic;
        letter:out std_logic_vector(7 downto 0) -- Esta saida aqui para ser conectada aos leds
    );
end lcd;

architecture hardware of lcd is

    component kb_code port(
        clk: in std_logic;
        rst: in std_logic;
        ps2d: in std_logic;
        ps2c: in std_logic;
        rd_key_code: in std_logic;
        key_code: out std_logic_vector(7 downto 0);
        kb_buf_empty: out std_logic
    );
    end component kb_code;

    type mstate is(
        --Initialization states
        stFunctionSet,
        stDisplayCtrlSet,
        stDisplayClear,
        --Delay states
        stPowerOn_Delay,
        stFunctionSet_Delay,
        stDisplayCtrlSet_Delay,
        stDisplayClear_Delay,
        --Display charachters and perform standard operations
        stInitDne,
        stActWr,
        stCharDelay --Write delay for operations
    );

    --Write control state machine
    type wstate is (
        stRW, --set up RS and RW
        stEnable, --set up E
        stIdle --Write data on DB(0)-DB(7)
    );

    signal clkCount:std_logic_vector(5 downto 0);
    signal activateW:std_logic:= '0'; --Activate Write sequence
    signal count:std_logic_vector (16 downto 0):= "00000000000000000"; --15 bit count variable for timing delays
    signal delayOK:std_logic:= '0'; --High when count has reached the right delay time
    signal OneUSClk:std_logic; --Signal is treated as a 1 MHz clock
    signal stCur:mstate:= stPowerOn_Delay; --LCD control state machine
    signal stNext:mstate;
    signal stCurW:wstate:= stIdle; --Write control state machine
    signal stNextW:wstate;
    signal writeDone:std_logic:= '0'; --Command set finish
    signal right_letters:std_logic_vector(5 downto 0) := "000000"; --Shows which letters are correct
    signal rd_key_code:std_logic;
    signal key_read:std_logic_vector(7 downto 0);
    signal key_saved:std_logic_vector(7 downto 0);
    signal kb_empty:std_logic;
    signal counter:unsigned(3 downto 0):="1011";
    signal break:std_logic:='0'; --Indica que o jogo acabou
    type LCD_CMDS_T is array(integer range 21 downto 0) of std_logic_vector (9 downto 0);

    signal LCD_CMDS : LCD_CMDS_T := (
        0 => "00"&X"3C", --Function Set
        1 => "00"&X"0C", --Display ON, Cursor OFF, Blink OFF
        2 => "00"&X"01", --Clear Display
        3 => "00"&X"02", --return home

        4 => "10"&X"44",  --D
        5 => "10"&X"3A",  --:
        6 => "10"&X"20",  --Space 
        7 => "10"&X"41",  --A
        8 => "10"&X"4E",  --N
        9 => "10"&X"49",  --I
        10 => "10"&X"4D", --M
        11 => "10"&X"41", --A
        12 => "10"&X"4C", --L

        13 => "00"&X"C0", --Line below

        14 => "10"&X"5F", -- "_"
        15 => "10"&X"5F", -- "_"
        16 => "10"&X"5F", -- "_"
        17 => "10"&X"5F", -- "_"
        18 => "10"&X"5F", -- "_"
        19 => "10"&X"5F", -- "_"
        20 => "00"&X"CC",
        21 => "10"&X"36"  -- 6
    );
    signal lcd_cmd_ptr : integer range 0 to LCD_CMDS'HIGH + 1 := 0;

    --At the beginning of the game, the phrase "HANGGER" appears on the top line, while "____" appears on the second line,
    --followed by the number 6, which is the initial number of lives.
begin

    kb_code_label: kb_code 
        port map(
            clk => CLK,
            rst => rst,
            ps2d => ps2d,
            ps2c => ps2c,
            rd_key_code => rd_key_code,
            key_code => key_read,
            kb_buf_empty => kb_empty
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if (kb_empty = '1') then
                rd_key_code <= '0';
            elsif (kb_empty = '0') then
                letter <= key_read;
                key_saved <= key_read;
                
                if(
                    (break = '0') and
                    (key_saved /= "01000001") and --A
                    (key_saved /= "01000010") and --B
                    (key_saved /= "01000101") and --E
                    (key_saved /= "01001100") and --L
                    (key_saved /= "01001000")     --H
                ) then
                    counter <= counter - 1;
                end if;
                rd_key_code <= '1';
            end if;
        end if;
    end process;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                right_letters <= (others => '0'); -- Resets all hits
            elsif break = '0' then
                --A
                if key_saved = X"41" then
                    right_letters(5) <= '1'; -- A (first position)
                    right_letters(0) <= '1'; -- A (last position)
                end if;
                --B
                if key_saved = X"42" then
                    right_letters(4) <= '1';
                end if;
                --E
                if key_saved = X"45" then
                    right_letters(3) <= '1';
                end if;
                --L
                if key_saved = X"4C" then
                    right_letters(2) <= '1';
                end if;
                --H
                if key_saved = X"48" then
                    right_letters(1) <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Displays "A" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(14) <= "10"&X"41" when -- Letra A
        (right_letters(5) = '1') 
    else 
        "10"&X"5F"; -- "_"

    -- Displays "B" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(15) <= "10"&X"42" when -- Letra B
        (right_letters(4) = '1') 
    else 
        "10"&X"5F"; -- "_"

    -- Displays "E" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(16) <= "10"&X"45" when -- Letra E
        (right_letters(3) = '1') 
    else 
        "10"&X"5F"; -- "_"

    -- Displays "L" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(17) <= "10"&X"4C" when -- Letra L
        (right_letters(2) = '1') 
    else 
        "10"&X"5F"; -- "_"

    -- Displays "H" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(18) <= "10"&X"48" when -- Letra H
        (right_letters(1) = '1') 
    else 
        "10"&X"5F"; -- "_"

    -- Displays "A" if that letter was correct, otherwise it displays "_"
    LCD_CMDS(19) <= "10"&X"41" when -- Letra A
        (right_letters(0) = '1') 
    else
        "10"&X"5F"; -- "_"

    -- Shows the number of lives
    LCD_CMDS(21) <= 
        "10"&X"36" when
            (counter = 11) 
    else
        "10"&X"36" when 
            (counter = 10) 
    else
        "10"&X"35" when 
            (counter = 9) 
    else
        "10"&X"35" when 
            (counter = 8) 
    else
        "10"&X"34" when 
            (counter = 7)
    else
        "10"&X"34" when 
            (counter = 6)
    else
        "10"&X"33" when 
            (counter = 5) 
    else
        "10"&X"33" when 
            (counter = 4)
    else
        "10"&X"32" when 
            (counter = 3)
    else
        "10"&X"32" when 
            (counter = 2)
    else
        "10"&X"31" when
            (counter < 2);

    -- Zero lives the game is over: break = 1, or get the word right
    break <= '1' when(
        (LCD_CMDS(21) = "10"&X"30")
    or
        (
            -- Got the word right
            LCD_CMDS(14) = "10"&X"41" and
            LCD_CMDS(15) = "10"&X"42" and
            LCD_CMDS(16) = "10"&X"44" and
            LCD_CMDS(17) = "10"&X"4C" and
            LCD_CMDS(18) = "10"&X"48" and
            LCD_CMDS(19) = "10"&X"41"
        )
    );


    -- This process counts to 50, and then resets. It is used to divide the clock
    process(CLK, oneUSClk)
    begin
        if(CLK = '1' and CLK'event) then
            clkCount <= clkCount + 1;
        end if;
    end process;

    -- This makes oneUSClock peak once every 1 microsecond
    oneUSClk <= clkCount(5);
    
    -- This process incriments the count variable unless delayOK = 1.
    process(oneUSClk, delayOK)
    begin
        if(oneUSClk = '1' and oneUSClk'event) then
            if delayOK = '1' then
                count <= "00000000000000000";
            else
                count <= count + 1;
            end if;
        end if;
    end process;

    --This goes high when all commands have been run
    writeDone <= '1' when 
        (lcd_cmd_ptr = LCD_CMDS'HIGH + 1)
    else 
        '0';

    --rdone <= '1' when stCur = stWait else '0';
    --Increments the pointer so the statemachine goes through the commands
    process(lcd_cmd_ptr, oneUSClk)
    begin
        if(oneUSClk = '1' and oneUSClk'event) then
            if((stNext = stInitDne or stNext = stDisplayCtrlSet or stNext = stDisplayClear) and writeDone = '0') then
                lcd_cmd_ptr <= lcd_cmd_ptr + 1;
            elsif stCur = stPowerOn_Delay or stNext = stPowerOn_Delay then
                lcd_cmd_ptr <= 0;
            elsif writeDone = '1' then
                lcd_cmd_ptr <= 3;
            else
                lcd_cmd_ptr <= lcd_cmd_ptr;
            end if;
        end if;
    end process;

    -- Determines when count has gotten to the right number, depending on the
    delayOK <= '1' when(
        (stCur = stPowerOn_Delay and count = "00100111001010010") or --20050
        (stCur = stFunctionSet_Delay and count = "00000000000110010") or --50
        (stCur = stDisplayCtrlSet_Delay and count = "00000000000110010") or --50
        (stCur = stDisplayClear_Delay and count = "00000011001000000") or --1600
        (stCur = stCharDelay and count = "11111111111111111") --Max Delay for character writes and shifts
    ) 
    else '0';

    -- This process runs the LCD status state machine
    process(oneUSClk, rst)
    begin
        if oneUSClk = '1' and oneUSClk'Event then
            if rst = '1' then
                stCur <= stPowerOn_Delay;
            else
                stCur <= stNext;
            end if;
        end if;
    end process;

    -- This process generates the sequence of outputs needed to initialize and write to the LCD screen
    process(stCur, delayOK, writeDone, lcd_cmd_ptr)
    begin
        case stCur is

            -- Delays the state machine for 20ms which is needed for proper startup.
            when stPowerOn_Delay =>
                if delayOK = '1' then
                    stNext <= stFunctionSet;
                else
                    stNext <= stPowerOn_Delay;
                end if;

                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';

            -- This issuse the function set to the LCD as follows
            -- 8 bit data length, 2 lines, font is 5x8.
            when stFunctionSet =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '1';
                stNext <= stFunctionSet_Delay;

            --Gives the proper delay of 37us between the function set and
            --the display control set.
            when stFunctionSet_Delay =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';
                if delayOK = '1' then
                    stNext <= stDisplayCtrlSet;
                else
                    stNext <= stFunctionSet_Delay;
                end if;

            --Issuse the display control set as follows
            --Display ON, Cursor OFF, Blinking Cursor OFF.
            when stDisplayCtrlSet =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '1';
                stNext <= stDisplayCtrlSet_Delay;

            --Gives the proper delay of 37us between the display control set
            --and the Display Clear command.
            when stDisplayCtrlSet_Delay =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';
                if delayOK = '1' then
                    stNext <= stDisplayClear;
                else
                    stNext <= stDisplayCtrlSet_Delay;
                end if;

            --Issues the display clear command.
            when stDisplayClear =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '1';
                stNext <= stDisplayClear_Delay;

            --Gives the proper delay of 1.52ms between the clear command
            --and the state where you are clear to do normal operations.
            when stDisplayClear_Delay =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';
                if delayOK = '1' then
                    stNext <= stInitDne;
                else
                    stNext <= stDisplayClear_Delay;
                end if;

            --State for normal operations for displaying characters, changing the
            --Cursor position etc.
            when stInitDne =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';
                stNext <= stActWr;

            when stActWr =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '1';
                stNext <= stCharDelay;

            --Provides a max delay between instructions.
            when stCharDelay =>
                RS <= LCD_CMDS(lcd_cmd_ptr)(9);
                RW <= LCD_CMDS(lcd_cmd_ptr)(8);
                LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
                activateW <= '0';
                if delayOK = '1' then
                    stNext <= stInitDne;
                else
                    stNext <= stCharDelay;
                end if;
        end case;
    end process;

    --This process runs the write state machine
    process(oneUSClk, rst)
    begin
        if oneUSClk = '1' and oneUSClk'Event then
            if rst = '1' then
                stCurW <= stIdle;
            else
                stCurW <= stNextW;
            end if;
        end if;
    end process;

    --This genearates the sequence of outputs needed to write to the LCD screen
    process(stCurW, activateW)
    begin
        case stCurW is
            --This sends the address across the bus telling the DIO5 that we are
            --writing to the LCD, in this configuration the adr_lcd(2) controls the
            --enable pin on the LCD
            when stRw =>
                OE <= '0';
                stNextW <= stEnable;

             --This adds another clock onto the wait to make sure data is stable on
            --the bus before enable goes low. The lcd has an active falling edge
            --and will write on the fall of enable
            when stEnable =>
                OE <= '0';
                stNextW <= stIdle;

            --Waiting for the write command from the instuction state machine
            when stIdle =>
                OE <= '1';
                if activateW = '1' then
                    stNextW <= stRw;
                else
                    stNextW <= stIdle;
                end if;
        end case;
    end process;
end hardware;