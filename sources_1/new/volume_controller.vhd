library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**23 	-- Inclusive 
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

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_controller;

architecture Behavioral of volume_controller is


constant mid_value : signed(VOLUME_WIDTH downto 0) := to_signed(2**(VOLUME_WIDTH-1), VOLUME_WIDTH+1); --aggiungiamo un bit per il segno;
constant mid_step : integer := 2**(VOLUME_STEP_2-1); -- 32   utilizato per calcolare l'esponente:  ((volume-mid_value) + mid_step)\64 = exponent

--vettori utilizzati per verificare se avviene l'overflow
constant all_zero : std_logic_vector(m_axis_tdata'RANGE) := (others =>'0'); 
constant all_one : std_logic_vector(m_axis_tdata'RANGE) := (others =>'1');

signal sign_exponent : std_logic := '0'; -- '0' positivo o nullo; '1' negativo;
signal volume_signed : signed(VOLUME_WIDTH downto 0) := (others => '0'); --registro in cui salviamo (volume - 512)
signal abs_volume : signed(VOLUME_WIDTH downto 0) := (others => '0'); --valore assoluto di volume signed;
signal exponent : unsigned(VOLUME_WIDTH-VOLUME_STEP_2-1 downto 0) := (others => '0');  --ci dice il modulo dell'esponente di 2^x, cioè |x|

signal tdata_reg : std_logic_vector(m_axis_tdata'RANGE) := (others => '0');
signal tlast_reg : std_logic := '0';

signal s_tready_reg : std_logic := '0'; --per leggere le uscite
signal m_tvalid_reg : std_logic := '0';

signal flag_mul : std_logic := '0'; --flag per moltiplicazione;


signal sign_exp_1 : std_logic := '0';
signal sign_exp_2 : std_logic := '0';

signal volume_1: signed(VOLUME_WIDTH downto 0) := (others => '0');

signal flag_start : std_logic := '1';

begin


	s_axis_tready <= s_tready_reg;
	m_axis_tvalid <= m_tvalid_reg;


--------- calcolo esponente----------------

	process(aclk,aresetn) --calcolo esponente, viene calcolato ad ogni ciclo di clock ma utilizzato solo quando nel secondo process viene acquisito un dato;
    begin                 

		if aresetn = '0' then

			sign_exponent <= '0';
			sign_exp_1 <= '0';
			sign_exp_2 <= '0';
			volume_signed <= (others => '0');
			volume_1 <= (others => '0');
			abs_volume <= (others => '0');
			exponent <= (others => '0');


		elsif rising_edge(aclk) then  --qui implementiamo la seguente formula per il calcolo dell'esponente (volume-mid_value) + mid_step)\64 = exponent



			volume_signed <= signed('0' & volume) - mid_value;
			volume_1 <= volume_signed; -- per avere il corretto valore di volume nel calcolo del valore assoluto

			sign_exponent <= volume_signed(volume_signed'HIGH);
			sign_exp_1 <= sign_exponent; -- ci servono per allineare exp al segno
			sign_exp_2 <= sign_exp_1; 
			
			if sign_exponent = '0' then

				abs_volume <= volume_1 + mid_step; 
				
			else

				abs_volume <= signed(not(std_logic_vector(volume_1))) + 1 + mid_step; -- signed è in complemento a due, per fare il valore assoluto, nego i bit e aggiungo 1

			end if;

			exponent <= unsigned(abs_volume(abs_volume'HIGH-1 downto VOLUME_STEP_2)); -- stiamo dividendo per 2**volume_step
			
				
		end if;
	end process;

	
---------- aquisizione, aleborazione e trasmissione---------------


	process(aclk, aresetn)
	begin

		if aresetn = '0' then
			
			tdata_reg <= (others => '0');
			tlast_reg <= '0';
			flag_mul <= '0';
			s_tready_reg <= '0';
			m_tvalid_reg <= '0';
			m_axis_tdata <= (others => '0');
			m_axis_tlast <= '0';
			flag_start <= '1';

		elsif rising_edge(aclk) then

			if flag_start = '1' then
				s_tready_reg <= '1';
				flag_start <= '0';
			end if;

			-- sampling dei valori

			if s_axis_tvalid = '1' and s_tready_reg='1' then 

				tdata_reg <= s_axis_tdata;
				tlast_reg <= s_axis_tlast;
				s_tready_reg <= '0';
				flag_mul <= '1';
			
			end if;

			if flag_mul = '1' then 

				if sign_exp_2 = '1' then --se l'esponente è negativo shiftiamo tdata a destra(dividiamo per 2**exp){no problemi di saturazione}
					
					m_axis_tdata(TDATA_WIDTH-to_integer(exponent)-1 downto 0) <= tdata_reg(tdata_reg'high downto to_integer(exponent));
					m_axis_tdata(m_axis_tdata'HIGH downto (TDATA_WIDTH-to_integer(exponent))) <= (others => tdata_reg(tdata_reg'HIGH));

				else --esponente positivo(alzo il volume), voglio evitare l'overflow, quindi dobbiamo far saturare il valore se necessario

					if tdata_reg(tdata_reg'HIGH) = '1' then --tdata negativo;
                        

						--controlliamo la condizione per cui avviene l'overflow: se nei primi bit ho tutti uni, lo shift non mi causa un'overflow (cioè il primo bit pari a zero del vettore di t_data, quando viene shiftato deve finire al massimo in seconda posizione più significativa, altrimenti ho overflow)
						if (tdata_reg(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent)) and all_one(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent))) = all_one(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent)) then
						
							m_axis_tdata(m_axis_tdata'HIGH downto to_integer(exponent)) <= tdata_reg(TDATA_WIDTH-to_integer(exponent)-1 downto 0);
							m_axis_tdata(to_integer(exponent)-1 downto 0) <= (others => '0');
							
						else
        
		    				m_axis_tdata <= std_logic_vector(to_signed(LOWER_BOUND, m_axis_tdata'LENGTH));

						end if;

					else --tdata positivo;

						--controlliamo la condizione per cui avviene l'overflow: se nei primi bit ho tutti zeri, lo shift non mi causa un'overflow (cioè il primo bit pari a uno del vettore di t_data, quando viene shiftato deve finire al massimo in seconda posizione più significativa, altrimenti ho overflow)
						if (tdata_reg(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent)) or all_zero(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent))) = all_zero(tdata_reg'HIGH downto tdata_reg'HIGH - to_integer(exponent)) then
							
							m_axis_tdata(m_axis_tdata'HIGH downto to_integer(exponent)) <= tdata_reg(TDATA_WIDTH - to_integer(exponent)-1 downto 0);
							m_axis_tdata(to_integer(exponent)-1 downto 0) <= (others => '0');

						else

							m_axis_tdata <= std_logic_vector(to_signed(HIGHER_BOUND, m_axis_tdata'LENGTH));
							
						end if;

					end if;
					
			    end if;

				flag_mul <= '0';
				m_tvalid_reg <= '1';
			    m_axis_tlast <= tlast_reg;
				
			end if;

			--- trasmissione dei valori
			if m_tvalid_reg = '1' and m_axis_tready = '1' then

				m_tvalid_reg <= '0';
				s_tready_reg <= '1';

			end if;

		end if;
		

		
	end process;

	



end Behavioral;

