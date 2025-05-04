library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter_en is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		enable_filter	: in std_logic
	);
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is

	constant PREVIOUS_VALUE : integer := 2**FILTER_ORDER_POWER;

	type matrix is array (0 to PREVIOUS_VALUE-1) of std_logic_vector(s_axis_tdata'RANGE);  
																						   
	signal memory_right : matrix := (others => (others => '0')); -- mi serve la matrice per salvare i precedenti valori per i due lati
	signal memory_left : matrix := (others => (others => '0'));

	signal s_tready_reg : std_logic := '0';
	signal m_tvalid_reg : std_logic := '0';

	signal sum_reg_l : signed(m_axis_tdata'HIGH + FILTER_ORDER_POWER downto 0) := (others => '0'); -- nel registro sommo tutti i precedenti valori, e in un secondo momento li dividerò per il numero totale di valori con uno shift
	signal sum_reg_r : signed(m_axis_tdata'HIGH + FILTER_ORDER_POWER downto 0) := (others => '0');

	signal average_flag : std_logic := '0';

	signal tlast_reg : std_logic := '0';
	
	signal flag_start : std_logic := '1';

	begin

	s_axis_tready <= s_tready_reg;
	m_axis_tvalid <= m_tvalid_reg;




	process(aclk, aresetn)
  	begin

		if aresetn = '0' then

			s_tready_reg <= '0';
			m_tvalid_reg <= '0';
			memory_left <= (others => (others => '0'));
			memory_right <= (others => (others => '0'));
			sum_reg_l <= (others => '0');
			sum_reg_r <= (others => '0');
			m_axis_tdata <= (others => '0');
			m_axis_tlast <= '0';
			average_flag <= '0';
			tlast_reg <= '0';
			flag_start <= '1';
			

		elsif rising_edge(aclk) then

			if flag_start = '1' then
                s_tready_reg <= '1';
                flag_start <= '0';
            end if;

			------ acquisizione dei dati e processamento

			if s_tready_reg = '1' and s_axis_tvalid = '1' then

				if s_axis_tlast = '0' then  -- in base al valore di tlast, modifico i valori nella matrice e nella somma

					memory_left <= s_axis_tdata & memory_left(memory_left'LOW to memory_left'HIGH-1); --cancello il valore meno recente

					sum_reg_l <= sum_reg_l + signed(s_axis_tdata) - signed(memory_left(memory_left'HIGH)); -- nella somma totale tolgo il valore meno recente e aggiungo il nuovo valore

				else

					memory_right <= s_axis_tdata & memory_right(memory_right'LOW to memory_right'HIGH-1); 

					sum_reg_r <= sum_reg_r + signed(s_axis_tdata) - signed(memory_right(memory_right'HIGH));

				end if;


				if enable_filter = '0' then -- se non ho l'enable attivo, passo i valori che ho ricevuto in ingresso

					m_axis_tdata <= s_axis_tdata;
					m_axis_tlast <= s_axis_tlast;
					m_tvalid_reg <= '1';

				else  -- altrimenti in uscita devo mettere la media

					average_flag <= '1';
					tlast_reg <= s_axis_tlast;

				end if;

				s_tready_reg <= '0';


			end if;

			-- gestione dell'avarage


			if average_flag = '1' then

				average_flag <= '0';
				m_tvalid_reg <= '1';
				m_axis_tlast <= tlast_reg;
				
				if tlast_reg = '0' then

					m_axis_tdata <= std_logic_vector(sum_reg_l(sum_reg_l'HIGH downto FILTER_ORDER_POWER)); -- stiamo facendo uno shift pari a FILTER_ORDER_POWER                        

				else

					m_axis_tdata <= std_logic_vector(sum_reg_r(sum_reg_r'HIGH downto FILTER_ORDER_POWER));
					
				end if;
			
			end if;


			----- trasmissione dei dati

			if m_axis_tready = '1' and m_tvalid_reg = '1' then

				s_tready_reg <= '1';
				m_tvalid_reg <= '0';

			end if;


		end if;
		
		
	end process;


end Behavioral; 