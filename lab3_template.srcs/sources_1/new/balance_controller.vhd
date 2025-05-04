library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is

	constant mid_value : signed(BALANCE_WIDTH downto 0) := to_signed(2**(BALANCE_WIDTH-1), BALANCE_WIDTH+1);
	constant mid_step : integer := 2**(BALANCE_STEP_2-1);

	signal sign_exponent : std_logic := '0'; -- '0' non negativo '1' negativo; supponiamo che all'inizio il joystick non è mosso
	signal balance_signed : signed(BALANCE_WIDTH downto 0) := (others => '0');
	signal abs_balance : signed(BALANCE_WIDTH downto 0) := (others => '0');
	signal exponent : unsigned(BALANCE_WIDTH-BALANCE_STEP_2-1 downto 0) := (others => '0');

	signal tdata_reg : std_logic_vector(m_axis_tdata'RANGE) := (others => '0');
	signal s_tready_reg : std_logic := '0';
	signal m_tvalid_reg : std_logic := '0';
	signal tlast_reg : std_logic := '0';

	signal data_ready : std_logic:='0';
	
    signal balance_1: signed(BALANCE_WIDTH downto 0) := (others => '0');
	signal sign_exp_1 : std_logic := '0';
	signal sign_exp_2 : std_logic := '0';

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
			balance_signed <= (others => '0');
			balance_1 <= (others => '0');
			abs_balance <= (others => '0');
			exponent <= (others => '0');


		elsif rising_edge(aclk) then  --qui implementiamo la seguente formula per il calcolo dell'esponente (volume-mid_value) + mid_step)\64 = exponent

			balance_signed <= signed('0' & balance) - mid_value;
			balance_1 <= balance_signed; -- per avere il corretto valore di volume nel calcolo del valore assoluto

			sign_exponent <= balance_signed(balance_signed'HIGH);
			sign_exp_1 <= sign_exponent; -- ci servono per allineare exp al segno
			sign_exp_2 <= sign_exp_1; 
			
			if sign_exponent = '0' then

				abs_balance <= balance_1 + mid_step; 
				
			else

				abs_balance <= signed(not(std_logic_vector(balance_1))) + 1 + mid_step; -- signed è in complemento a due, per fare il valore assoluto, nego i bit e aggiungo 1

			end if;

			exponent <= unsigned(abs_balance(abs_balance'HIGH-1 downto BALANCE_STEP_2)); -- stiamo dividendo per 2**volume_step
			
				
		end if;
	end process;


---------- aquisizione, aleborazione e trasmissione---------------
    

	process(aclk,aresetn)
    begin
		
		if aresetn = '0' then

			tdata_reg 		<= (others => '0');
			m_tvalid_reg 	<= '0';
			tlast_reg 		<= '0';
			s_tready_reg 	<= '0';
			data_ready 		<= '0';
			m_axis_tlast 	<= '0';
			m_axis_tdata	<= (others => '0');
			s_tready_reg <= '0';
			flag_start <= '1';
			
		elsif rising_edge(aclk) then

			if flag_start = '1' then
				s_tready_reg <= '1';
				flag_start <= '0';
			end if;

			-- sampling dei valori

			if s_axis_tvalid = '1' and s_tready_reg = '1' then

				tdata_reg <= s_axis_tdata;
				tlast_reg <= s_axis_tlast;
				s_tready_reg <= '0';
				data_ready <= '1';
				
			end if;

			if data_ready = '1' then

				if tlast_reg = sign_exp_2 then --quando arriva un dato relativo all'altro canale rispetto la direzione del jstk, andiamo a ridurre il suo volume, altrimenti il dato passa inalterato

					m_axis_tdata(TDATA_WIDTH-to_integer(exponent)-1 downto 0) <= tdata_reg(tdata_reg'high downto to_integer(exponent));
				    m_axis_tdata(m_axis_tdata'HIGH downto (TDATA_WIDTH-to_integer(exponent))) <= (others => tdata_reg(tdata_reg'HIGH));
					m_axis_tlast <= tlast_reg;

				else

					m_axis_tdata <= tdata_reg;
					m_axis_tlast <= tlast_reg;

				end if;
				
				data_ready <= '0';
				m_tvalid_reg <= '1';

			end if;


			-- trasmissione dei dati

			if m_tvalid_reg = '1' and m_axis_tready = '1' then

				m_tvalid_reg <= '0';
				s_tready_reg <= '1';
			
			end if;

		end if;
	end process;

end Behavioral;
