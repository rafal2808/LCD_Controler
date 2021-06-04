LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY lcd_controller IS
  GENERIC(
    clk_freq       :  INTEGER    := 100;   --czestotliwosc zegara w MHz
    display_lines  :  STD_LOGIC  := '1';   --ilosc wierszy (0 = 1, 1 = 2)
    character_font :  STD_LOGIC  := '0';   --czcionka (0 = 5x8, 1 = 5x10)
    display_on_off :  STD_LOGIC  := '1';   --ekran on/off (0 = off, 1 = on)
    cursor         :  STD_LOGIC  := '0';   --kursor on/off (0 = off, 1 = on)
    blink          :  STD_LOGIC  := '0';   --mrugajacy kursor on/off (0 = off, 1 = on)
    inc_dec        :  STD_LOGIC  := '1';   --inkrementacja/dekrementacja (0 = dekrementacja, 1 = inkrementacja)
    shift          :  STD_LOGIC  := '0');  --przesuniecie on/off (0 = off, 1 = on)
  PORT(
    clk        : IN   STD_LOGIC;                     --zegar
    reset_n    : IN   STD_LOGIC;                     --reset (aktywowany stanem niskim)
    lcd_enable : IN   STD_LOGIC;                     --rozpoczecie transmisji
    lcd_bus    : IN   STD_LOGIC_VECTOR(9 DOWNTO 0);  --dane dla lcd (calosc)
    busy       : OUT  STD_LOGIC := '1';              --flaga zajetosci
    rw, rs, e  : OUT  STD_LOGIC;                     --read/write, setup/data, enable
    lcd_data   : OUT  STD_LOGIC_VECTOR(7 DOWNTO 0)); --dane dla lcd
END lcd_controller;

ARCHITECTURE controller OF lcd_controller IS
  TYPE CONTROL IS(power_up, initialize, ready, send);	--deklaracja maszyny stanow
  SIGNAL  state  : CONTROL;
BEGIN
  PROCESS(clk)
    VARIABLE clk_count : INTEGER := 0; --zmienna czasu
  BEGIN
    IF(clk'EVENT and clk = '1') THEN

      CASE state IS
         
        
        WHEN power_up =>
          busy <= '1';
          IF(clk_count < (50000 * clk_freq)) THEN    --50ms
            clk_count := clk_count + 1;
            state <= power_up;
          ELSE                                       
            clk_count := 0;
            rs <= '0';
            rw <= '0';
            lcd_data <= "00110000";
            state <= initialize;
          END IF;
          
        
        WHEN initialize =>
          busy <= '1';
          clk_count := clk_count + 1;
          IF(clk_count < (10 * clk_freq)) THEN       --ustawienie wielkosci ekrani i znakow
            lcd_data <= "0011" & display_lines & character_font & "00";
            e <= '1';
            state <= initialize;
          ELSIF(clk_count < (60 * clk_freq)) THEN    --50 us
            lcd_data <= "00000000";
            e <= '0';
            state <= initialize;
          ELSIF(clk_count < (70 * clk_freq)) THEN    --ekran on/off 
            lcd_data <= "00001" & display_on_off & cursor & blink;
            e <= '1';
            state <= initialize;
          ELSIF(clk_count < (120 * clk_freq)) THEN   --50 us
            lcd_data <= "00000000";
            e <= '0';
            state <= initialize;
          ELSIF(clk_count < (130 * clk_freq)) THEN   --lcd clear
            lcd_data <= "00000001";
            e <= '1';
            state <= initialize;
          ELSIF(clk_count < (2130 * clk_freq)) THEN  --2 ms
            lcd_data <= "00000000";
            e <= '0';
            state <= initialize;
          ELSIF(clk_count < (2140 * clk_freq)) THEN  --ink/dek, przesuniecie
            lcd_data <= "000001" & inc_dec & shift;
            e <= '1';
            state <= initialize;
          ELSIF(clk_count < (2200 * clk_freq)) THEN  --60 us
            lcd_data <= "00000000";
            e <= '0';
            state <= initialize;
          ELSE                                       
            clk_count := 0;
            busy <= '0';
            state <= ready;
          END IF;    
       
        
        WHEN ready =>
          IF(lcd_enable = '1') THEN
            busy <= '1';
            rs <= lcd_bus(9);
            rw <= lcd_bus(8);
            lcd_data <= lcd_bus(7 DOWNTO 0);
            clk_count := 0;            
            state <= send;
          ELSE
            busy <= '0';
            rs <= '0';
            rw <= '0';
            lcd_data <= "00000000";
            clk_count := 0;
            state <= ready;
          END IF;
        
             
        WHEN send =>
          busy <= '1';
          IF(clk_count < (50 * clk_freq)) THEN       --50us
            IF(clk_count < clk_freq) THEN             
              e <= '0';
            ELSIF(clk_count < (14 * clk_freq)) THEN    
              e <= '1';
            ELSIF(clk_count < (27 * clk_freq)) THEN    
              e <= '0';
            END IF;
            clk_count := clk_count + 1;
            state <= send;
          ELSE
            clk_count := 0;
            state <= ready;
          END IF;

      END CASE;    
  
      
      IF(reset_n = '0') THEN
          state <= power_up;
      END IF;
    
    END IF;
  END PROCESS;
END controller;