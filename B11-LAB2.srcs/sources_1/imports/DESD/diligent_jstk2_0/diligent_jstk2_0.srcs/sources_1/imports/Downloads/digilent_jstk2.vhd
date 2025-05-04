library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity digilent_jstk2 is
	generic (
		DELAY_US		: integer := 25;    -- Delay (in us) between two packets
		CLKFREQ		 	: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ 	: integer := 66_666 -- Frequency of the SPI SCLK clock signal (in Hz)
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

		-- Joystick and button values read from the module
		jstk_x			: out std_logic_vector(9 downto 0);
		jstk_y			: out std_logic_vector(9 downto 0);
		btn_jstk		: out std_logic;
		btn_trigger		: out std_logic;

		-- LED color to send to the module
		led_r			: in std_logic_vector(7 downto 0);
		led_g			: in std_logic_vector(7 downto 0);
		led_b			: in std_logic_vector(7 downto 0)
	);
end digilent_jstk2;


architecture Behavioral of digilent_jstk2 is

	----------------COSTANTI-----------------------------------------

	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
	constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";
	constant DELAY_CYCLES : integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;
    -- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
	------------------------------------------------------------
	constant N_BYTE_MAX : integer := 5; --numero di byte da mandare/ricevere al/dal joystick


	--------------------TYPE--------------------------------------------

	type DATA_STACK is array (0 to N_BYTE_MAX-1) of std_logic_vector(s_axis_tdata'RANGE); -- per rendere trasmissione atomica


	---------------------SIGNALS---------------------------------------

	------------DATA->FPGA-------------------------
	signal COUNT_BYTE_FPGA : integer 	range 0 to N_BYTE_MAX-1 := 0; --numero di byte validi arrivati dal joystick
	signal BYTE_STACK_FULL : std_logic := '0'; --flag alta se lo stack è pieno;

	signal DATA_TO_FPGA : DATA_STACK := (others => (others => '0'));--array in cui salviamo i dati ricevuti

	-----------DATA->PC--------------------------------
	signal DATA_TO_JSTK : DATA_STACK := (0 => CMDSETLEDRGB, others => (others => '0'));--stack in cui salviamo i dati da inviare al joystick
	signal running : std_logic := '0'; --flag alta se stiamo inviando i byte al joystick o stiamo aspettando il delay 

	signal COUNT_BYTE_JSTK : integer range 0 to N_BYTE_MAX - 1 	:= 0;
	signal COUNT_DELAY : integer range 0 to DELAY_CYCLES - 1 := 0;

	signal m_axis_tvalid_reg : std_logic := '0';
	


begin

	---------------------associazione output----------------
    m_axis_tdata <= DATA_TO_JSTK(COUNT_BYTE_JSTK);
	m_axis_tvalid <= m_axis_tvalid_reg;

	---------------JSKT -> FPGA--------------------
	--process per ricevere dati dal joystick e mandarli al fpga
	process(aclk,aresetn)
  
	begin

		if aresetn = '0' then

			COUNT_BYTE_FPGA <= 0;
			BYTE_STACK_FULL <= '0';
			DATA_TO_FPGA <= (others => (others => '0'));

		elsif rising_edge(aclk) then

			if BYTE_STACK_FULL = '1' then   --associazione DATA_TO_FPGA all'uscita quando lo stack è pieno
				
				BYTE_STACK_FULL <= '0';

				jstk_x <= DATA_TO_FPGA(1)(1 downto 0) & DATA_TO_FPGA(0);
				jstk_Y <= DATA_TO_FPGA(3)(1 downto 0) & DATA_TO_FPGA(2);

				btn_jstk <= DATA_TO_FPGA(4)(0);
				btn_trigger <= DATA_TO_FPGA(4)(1);

			end if;

			if s_axis_tvalid = '1' then

				--salviamo i byte in ingresso nello stack 
				DATA_TO_FPGA(COUNT_BYTE_FPGA) <= s_axis_tdata; 

				if COUNT_BYTE_FPGA = N_BYTE_MAX-1 then 

					COUNT_BYTE_FPGA <= 0;
					BYTE_STACK_FULL <= '1';
				    

				else

					COUNT_BYTE_FPGA <= COUNT_BYTE_FPGA + 1;

				end if;

			end if;

		end if;

	end process;


    ---------------FPGA -> JSTK---------------------

	--process for sending the leds values (l'altro modulo fa in modo che i valori dei led arrivino tutti insieme)
	process(aclk, aresetn)
    begin

		if aresetn = '0' then

			running <= '0';
			DATA_TO_JSTK <= (0 => CMDSETLEDRGB, others => (others => '0'));
			COUNT_DELAY <= 0;
			m_axis_tvalid_reg <= '0';

		elsif rising_edge(aclk) then
     
			if running = '0' then --salviamo coordinate dei led nell'array

				DATA_TO_JSTK(1) <= led_r;
				DATA_TO_JSTK(2) <= led_g;
				DATA_TO_JSTK(3) <= led_b;

				running <= '1'; 
				m_axis_tvalid_reg <= '1';

			elsif m_axis_tready = '1' and m_axis_tvalid_reg = '1' then  -- handshake
				
				if COUNT_BYTE_JSTK = N_BYTE_MAX - 1 then

					m_axis_tvalid_reg <= '0';   -- abbassiamo per aspettare il delay
					COUNT_BYTE_JSTK <= 0; 

				else
					
					COUNT_BYTE_JSTK <= COUNT_BYTE_JSTK + 1;

				end if;
				
			elsif m_axis_tvalid_reg = '0' then

				if COUNT_DELAY = DELAY_CYCLES - 1 then

					running <= '0';   -- abbiamo finito il delay, quindi riacquisiamo i dati
					COUNT_DELAY <= 0;

				else

					COUNT_DELAY <= COUNT_DELAY + 1;
								
				end if;

			end if;

		end if;

	end process;


end architecture;
