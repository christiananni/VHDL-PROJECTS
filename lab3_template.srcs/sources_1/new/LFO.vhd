    library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGTH	: integer := 24;
        JOYSTICK_LENGTH	: integer := 10;
        CLK_PERIOD_NS	: integer := 10;
        TRIANGULAR_COUNTER_LENGTH	: integer := 10 -- Triangular wave period length
    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            jstk_y          : in std_logic_vector(JOYSTICK_LENGTH-1 downto 0); --10 bit
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic; 
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

    --lfo_period := LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR*joystick_y

    constant LFO_COUNTER_BASE_PERIOD_US   : integer := 1000; -- Base period of the LFO counter in us 
    constant ADJUSTMENT_FACTOR : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position
    constant BASE_CYCLES : integer := (LFO_COUNTER_BASE_PERIOD_US * 1000)/CLK_PERIOD_NS;

    constant TOT_STEPS : integer := 2**TRIANGULAR_COUNTER_LENGTH; -- numero di gradini dell'onda triangolare  

    signal tdata_reg : std_logic_vector(CHANNEL_LENGTH-1 downto 0);
    signal tlast_reg : std_logic;
    signal s_tready_reg : std_logic := '0'; 
    signal m_tvalid_reg : std_logic := '0'; 

    signal number_of_cycles : unsigned( JOYSTICK_LENGTH*2-1 downto 0) := to_unsigned(BASE_CYCLES - 1, JOYSTICK_LENGTH*2 ); --inizializiamo a BASE_CYCLES - 1 perchè number_of_cycles parte da zero. 
    signal jstk_adjusted : unsigned( JOYSTICK_LENGTH*2-1 downto 0) := (others => '0'); --registro in cui viene salvato ADJUSTMENT_FACTOR * unsigned(jstk_y);
    signal counter_period : unsigned( JOYSTICK_LENGTH*2-1 downto 0) := (others => '0'); --contatore per tracciare la durata di un gradino

    signal triangular_counter : unsigned(TRIANGULAR_COUNTER_LENGTH downto 0) := (others => '0'); --bit in più per il segno
    signal triangular_counter_reg : unsigned(TRIANGULAR_COUNTER_LENGTH downto 0) := (others => '0'); --bit in più per il segno
    
    signal dir_flag : std_logic := '0'; --scalinata 0 sale, 1 scende

    signal mul_reg : std_logic_vector(m_axis_tdata'length + TRIANGULAR_COUNTER_LENGTH  downto 0) := (others => '0');  --bit in più per segno del triangular counter 35 bit
    signal div_reg : std_logic_vector(m_axis_tdata'length + TRIANGULAR_COUNTER_LENGTH  downto 0) := (others => '0');

    signal mul_done : std_logic := '0';
    signal do_mul : std_logic := '0';
    signal flag_new_data : std_logic := '0';

    signal flag_start : std_logic := '1';

begin

    s_axis_tready <= s_tready_reg; 
    m_axis_tvalid <= m_tvalid_reg; 
    
    process(aclk, aresetn)
    begin

        if aresetn = '0' then

            jstk_adjusted <= (others => '0');
            counter_period <= (others => '0');
            number_of_cycles <= to_unsigned(BASE_CYCLES - 1, number_of_cycles'length);
            triangular_counter <= (others => '0');
            dir_flag <= '0';
            s_tready_reg <= '0';
            m_axis_tdata <= (others => '0');
            m_axis_tlast <= '0';
            tdata_reg <= (others => '0');
            tlast_reg <= '0';
            do_mul <= '0';
            triangular_counter <= (others => '0');
            mul_reg <= (others => '0');
            mul_done <= '0';
            div_reg <= (others => '0');
            flag_new_data <= '0';
            m_tvalid_reg <= '0';
            
            flag_start <= '1';

        elsif rising_edge(aclk) then

            if flag_start = '1' then
                s_tready_reg <= '1';
                flag_start <= '0';
            end if;
            ------ generazione onda triangolare -------
            
            jstk_adjusted <= ADJUSTMENT_FACTOR * unsigned(jstk_y);
            
            if lfo_enable = '1' then --se l'lfo è attivo agiamo sul valore di counter_period(che va a definire la durata di uno scalino) 
                
                if counter_period = number_of_cycles  then

                    counter_period <= (others => '0');
                    number_of_cycles <= BASE_CYCLES - jstk_adjusted - 1;  -- siccome nella traccia ci viene detto che al centro abbiamo il base period, dobbiamo allineare il valore del jstk_y al centro
                                                                            -- il - 1 è perché number_of_cycles parte da 0
                                                                            
                    if dir_flag = '0' then -- in base alla direzione, scelgo se devo aumentare o diminuire triangular_counter (che in pratica mi inidica il gradino della scalinata)

                        if triangular_counter = TOT_STEPS - 2 then  

                            dir_flag <= not dir_flag;
                            
                        end if;
                                             
                        triangular_counter <= triangular_counter + 1;

                    else

                        if triangular_counter = 1 then                     

                            dir_flag <= not dir_flag;

                        end if;

                            triangular_counter <= triangular_counter - 1;

                        end if;
                    
                else

                    counter_period <= counter_period + 1;
                
                end if;
                
            end if;
                       
            ---- sampling dei valori ----

            if s_axis_tvalid = '1' and  s_tready_reg = '1' then 

                s_tready_reg <= '0';

                if lfo_enable = '0' then

                    m_axis_tdata <= s_axis_tdata;
                    m_axis_tlast <= s_axis_tlast;
                    m_tvalid_reg <= '1';
                    
                else

                    tdata_reg <= s_axis_tdata; 
                    tlast_reg <= s_axis_tlast; 
                    do_mul <= '1';
                    triangular_counter_reg <= triangular_counter;

                end if;

            end if;

            ------ elaborazione dei valori se lfo_enable è attivo ------

            -- moltiplicazione di t_data per l'onda triangolare
          
            if do_mul = '1' then

                mul_reg <= std_logic_vector(signed(tdata_reg) * signed(triangular_counter_reg));
                do_mul <= '0';         
                mul_done <= '1';

            end if;


            --- divisione della precedente moltiplicazione per il numero massimo di gradini           

            if mul_done = '1' then
                --shift di dieci bit a dx 
                div_reg(mul_reg'high downto mul_reg'high-TRIANGULAR_COUNTER_LENGTH + 1) <= (others => mul_reg(mul_reg'high));
                div_reg(mul_reg'high-TRIANGULAR_COUNTER_LENGTH downto 0) <= mul_reg(mul_reg'high downto TRIANGULAR_COUNTER_LENGTH);
                                                                                     
                mul_done <= '0';
                flag_new_data <= '1';

            end if;

            --- salvo il valore pronto alla trasmissione

            if flag_new_data = '1'then

                flag_new_data <= '0';
                m_tvalid_reg <= '1';
                m_axis_tlast <= tlast_reg;
                m_axis_tdata <= div_reg(CHANNEL_LENGTH-1 downto 0);
                
            end if;

            ------- trasmissione dei valori -----

            if m_tvalid_reg = '1' and m_axis_tready = '1' then

                m_tvalid_reg <= '0';
                s_tready_reg <= '1';
  
            end if;

        end if;

    end process;

end architecture;
