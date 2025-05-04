library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_level_controller is
    generic(
        NUM_LEDS 		: positive := 16;
        CHANNEL_LENGTH  : positive := 24;
        refresh_time_ms	: positive :=1;
        clock_period_ns	: positive :=10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led  			: out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGTH-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic

    );
end led_level_controller;

architecture Behavioral of led_level_controller is

    constant N_CYCLES       : integer := (refresh_time_ms*1_000_000)/clock_period_ns; -- numero di cicli per refreshare

    signal s_tready_reg     : std_logic := '0';

    signal sx_value         : unsigned(s_axis_tdata'RANGE)  := (others => '0');
    signal dx_value         : unsigned(s_axis_tdata'RANGE)  := (others => '0');

    signal flag_somma       : std_logic := '0';
    signal somma            : unsigned(s_axis_tdata'HIGH downto 0) := (others => '0'); 
    signal flag_media       : std_logic := '0';
    signal media            : std_logic_vector(s_axis_tdata'RANGE) := (others =>'0');
    signal media_reg        : std_logic_vector(s_axis_tdata'RANGE) := (others =>'0');

    signal flag_index       : std_logic := '0';
    signal counter_index    : integer range 0 to NUM_LEDS := NUM_LEDS ; -- mi indica il mumero di led spenti   

    signal go_to_led        : std_logic := '0';

    signal counter_cycles   : integer range 0 to N_CYCLES - 1 := 0;

    signal led_reg          : std_logic_vector(led'range) := (others => '0');


begin

    led <= led_reg;
    s_axis_tready <= s_tready_reg;

    process(aclk, aresetn)

    begin

        if aresetn = '0' then

            -- subito dopo che la scheda viene programmata o resetteta, senza audio in ingresso, abbiamo notato che rimangono accesi 8 led per pochi istanti per poi spegnersi gradualmente;
            -- tramite l'hardware debug abbiamo notato che questo comportamento ha origine nel modulo i2s il quale dopo il reset trasmette dei valori di tdata nell'ordine dei -50_000 che poco dopo si assestano
            -- al valore del rumore della sorgente. Non abbiamo trovato modo di risolvere questo fenomeno, in ogni caso questo non influisce sul corretto funzionamento della scheda; 

            sx_value <= (others => '0');
            dx_value <= (others => '0');
            flag_somma <= '0';
            somma <= (others => '0');
            flag_media <= '0';
            media <= (others => '0');
            counter_cycles <= 0;
            flag_index <= '0';
            media_reg <= (others => '0');
            go_to_led <= '1';
            led_reg <= (others => '0');
            counter_index <= NUM_LEDS;
            s_tready_reg <= '0'; 

        elsif rising_edge(aclk) then



            -- sampling
            s_tready_reg <= '1';

            if s_tready_reg = '1' and s_axis_tvalid = '1' then -- in questo caso, siccome non abbiamo la trasmissione, non abbiamo problemi ad essere sempre pronti a ricevere
                
                
                if s_axis_tlast = '0' then --capisco se salvare nel registro destro o sinistro
                
                    sx_value <= unsigned(abs(signed(s_axis_tdata)));
                       
                else

                    dx_value <= unsigned(abs(signed(s_axis_tdata)));
                    flag_somma <= '1'; -- facciamo la somma solo se abbiamo un nuovo valore destro e sinistro
                   
                end if;

                
           end if;


            -- calcolo della media 


            if flag_somma = '1' then -- facciamo la somma dei due canali in valore assoluto

                somma <= sx_value + dx_value; 
                flag_somma <= '0';
                flag_media <= '1';
        
            end if;

            if flag_media = '1' then -- facciamo la media

                media <= '0' & std_Logic_vector(somma(somma'HIGH downto 1)); --ho diviso per 2
                flag_media <= '0';
               
            end if;

            if counter_cycles = N_CYCLES - 1 then

                counter_cycles <= 0;
                flag_index <= '1'; 
                media_reg <= media; -- al refresh, salvo il valore della media che mi dir? quanti led accendere

            else

                counter_cycles <= counter_cycles + 1;


            end if;





            ------ individuazione del numero di led da spegnere

            -- controlliamo i bit a partire dal pi? significativo. Appena troviamo un '1', il valore salvato in counter_index ci dir? il numero di led pi? significativi (a sx) spenti
            -- questo perch? se ho per esempio "010101", i led dovranno essere "011111", cio? counter_index sar? 1
            if flag_index = '1' then

                if counter_index = NUM_LEDS - 1 and media_reg(media_reg'HIGH - counter_index) = '0' then

                    counter_index <= counter_index + 1;

                    flag_index <= '0';
                    go_to_led <= '1';
            
                elsif media_reg(media_reg'HIGH - counter_index) = '0' then 

                    counter_index <= counter_index + 1;

                else

                    flag_index <= '0';

                    go_to_led <= '1';

                end if;
            end if;


            if go_to_led = '1' then  ---inizializzazione leds;

                go_to_led <= '0';

                if counter_index = NUM_LEDS  then

                    led_reg <= (others => '0');

                elsif counter_index = 0 then -- non necessario ma lo lasciamo per eventuali glitch che potrebbero portare counter_index a 0

                    led_reg(led'high-1 downto 0) <= (others => '1');
                    led_reg(led'high) <= '0';

                else

                    led_reg(led'HIGH downto led'HIGH - counter_index + 1) <= (others => '0');
                    led_reg(led'HIGH - counter_index downto 0) <= (others => '1');


                end if;

                counter_index <= 0;

            end if;

      end if;

    end process;

end Behavioral;
