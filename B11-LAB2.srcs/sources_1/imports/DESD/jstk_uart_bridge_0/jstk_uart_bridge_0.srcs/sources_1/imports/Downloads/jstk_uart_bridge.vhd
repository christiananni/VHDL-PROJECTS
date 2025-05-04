library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jstk_uart_bridge is
	generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0"; -- Header of the packet
		TX_DELAY		: positive := 1_000_000;    -- Pause (in clock cycles) between two packets
		JSTK_BITS		: integer range 1 to 7 := 7    -- Number of bits of the joystick axis to transfer to the PC 
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the PC (i.e., joystick position and buttons state)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the PC (i.e., LED color)
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);
		s_axis_tready	: out STD_LOGIC;

		jstk_x			: in std_logic_vector(9 downto 0);
		jstk_y			: in std_logic_vector(9 downto 0);
		btn_jstk		: in std_logic;
		btn_trigger		: in std_logic;

		led_r			: out std_logic_vector(7 downto 0);
		led_g			: out std_logic_vector(7 downto 0);
		led_b			: out std_logic_vector(7 downto 0)
	);
end jstk_uart_bridge;

architecture Behavioral of jstk_uart_bridge is

	-----------------COSTANTI---------------------------------------

	constant N_BYTE_MAX : INTEGER := 4; --numero di byte in un pacchetto (header jx jy btns);
	constant N_COLOR_COORD : INTEGER := 3; --numero di coordinate rgb
	constant VECT_OF_ZEROS : std_logic_vector(m_axis_tdata'HIGH-JSTK_BITS downto 0) := (others => '0'); --vettore di zeri, per completare il byte da inviare al pc;

	-------------------TYPE-------------------------------------------

	type DATA_STACK is array (integer range <>) of std_logic_vector(s_axis_tdata'RANGE);

	---------signals fpga->pc-----------------------

	signal DATA_TO_PC : DATA_STACK(0 to 3) := (0 => HEADER_CODE, others => (others => '0')); --array in cui salviamo le inforamzioni per il pc
	signal m_axis_tvalid_reg : std_logic := '0'; 

	signal COUNT_BYTE_OUT : integer range 0 to 3 := 0; --contatore per definire la posizione nello stack;

	signal running : std_logic := '0'; --flag alta durante invio dei byte e delay;
	signal COUNT_DELAY : integer range 0 to TX_DELAY - 1 := 0;

	----------signals pc<-fpga -------------------

	signal s_axis_tready_reg : std_logic := '1';
	signal s_axis_tdata_reg : std_logic_vector(s_axis_tdata'RANGE) := (others => '0');
	
	signal DATA_TO_FPGA : DATA_STACK(0 to 2) := (others => (others => '0')); --array in cui salviamo le informazioni che arrivano dal pc (ci salviamo solo le coordinate dei colori); 
	signal COLOR_INDEX : integer range 0 to 2 := 0; --indice del byte da inviare

	signal HEADER_FOUND : std_logic := '0'; --flag alta quando header trovato;

	signal FINISHED : std_logic := '0'; --flag alta se tutto il pacchetto è stato ricevuto;
	

begin

	----------------- FPGA -> PC -------------------


	m_axis_tvalid <= m_axis_tvalid_reg;
	m_axis_tdata <= DATA_TO_PC(COUNT_BYTE_OUT);
	
	--PROCESS PER TRASMETTERE DATI AL PC
	process(aclk, aresetn)
    begin
		if aresetn = '0' then

			m_axis_tvalid_reg <= '0';
			COUNT_BYTE_OUT <= 0;
			COUNT_DELAY <= 0;
			running <= '0';
			DATA_TO_PC <= (0 => HEADER_CODE, others => (others => '0'));

		elsif rising_edge(aclk) then
     
			if running = '0' then

				--salviamo le coordinate e i bottoni del joystick nell'array; 
				-------allochiamo i bit tutti a destra
				DATA_TO_PC(1) <= VECT_OF_ZEROS & jsTk_x(jstk_x'HIGH downto jstk_x'LENGTH - JSTK_BITS); --x
				DATA_TO_PC(2) <= VECT_OF_ZEROS & jsTk_y(jstk_y'HIGH downto jstk_y'LENGTH - JSTK_BITS); --y        

				DATA_TO_PC(3) <= (0 => btn_jstk, 1 => btn_trigger, others => '0'); --bottoni
				
				m_axis_tvalid_reg <= '1';
				running <= '1';
				
				
			elsif m_axis_tready = '1' and m_axis_tvalid_reg = '1' then --invio dei byte al pc
				
				if COUNT_BYTE_OUT = N_BYTE_MAX - 1 then

					m_axis_tvalid_reg <= '0'; --dopo l'ultima handshake abbassiamo il tvalid per attendere il delay; 
					COUNT_BYTE_OUT <= 0;

				else
					
					COUNT_BYTE_OUT <= COUNT_BYTE_OUT + 1;
				
				end if;

			elsif m_axis_tvalid_reg = '0'  then --attesa delay

				if COUNT_DELAY = TX_DELAY - 1 then

					running <= '0'; --abbassiamo il running per acquisire nuovi dati nel data_stack
					COUNT_DELAY <= 0;

				else

					COUNT_DELAY <= COUNT_DELAY + 1;
								
				end if;

			end if;

		end if;

	end process;


	---------------- PC -> FPGA ------------------
	s_axis_tready <= s_axis_tready_reg;
    s_axis_tdata_reg <= s_axis_tdata;
	
	--PROCESS PER ACQUISIRE DATI DAL PC
	process(aclk,aresetn)
  	begin

		if aresetn = '0' then

			s_axis_tready_reg <= '1';

			FINISHED <= '0';
			COLOR_INDEX <= 0;
			HEADER_FOUND <= '0';
			DATA_TO_FPGA <= (others => (others => '0'));

			led_r <= x"00";
			led_g <= x"00";
			led_b <= x"00";

		elsif rising_edge(aclk) then

			if s_axis_tvalid = '1' and s_axis_tready_reg = '1' then

				if s_axis_tdata_reg = HEADER_CODE then

					HEADER_FOUND <= '1'; -- utile per non salvare pacchetti di questo tipo (all'accensione o dopo un reset) 0a 0a 0a c0
					COLOR_INDEX <= 0; --in questo modo il pacchetto riparte dall'inizio in caso di pacchetti incompleti (abbiamo assunto che rgb non possono assumere il valore dell'header)

				elsif HEADER_FOUND = '1' then -- salvataggio delle coordinate dei colori dopo che l'header è stato trovato

					DATA_TO_FPGA(COLOR_INDEX) <= s_axis_tdata_reg;
					
					if COLOR_INDEX = N_COLOR_COORD - 1 then

						COLOR_INDEX <= 0;
						HEADER_FOUND <= '0';
						FINISHED <= '1'; --tutte le coordinate sono state salvate quindi alziamo la flag
						s_axis_tready_reg <= '0';

					else

						COLOR_INDEX <= COLOR_INDEX + 1;

					end  if;
					
				end if;
				
			elsif FINISHED = '1' then --una volta che abbiamo il pacchetto completo associamo i byte alle corrette uscite (in questo ciclo il tready è basso)
			
				led_r <= DATA_TO_FPGA(0);
				led_g <= DATA_TO_FPGA(1);
				led_b <= DATA_TO_FPGA(2);

				FINISHED <= '0';
				s_axis_tready_reg <= '1';
				
			end if;

		end if;

	end process;
	

end architecture;

