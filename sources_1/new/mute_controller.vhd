library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
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

		mute			: in std_logic
	);
end mute_controller;


architecture Behavioral of mute_controller is



begin
	
	process(aclk, aresetn)
    begin
		if aresetn = '0' then

			m_axis_tlast <= '0';
			s_axis_tready <= '0';
			m_axis_tvalid <= '0';
			m_axis_tdata <= (others => '0');
			
		elsif rising_edge(aclk) then
			
			if mute = '1' then
			     m_axis_tdata <= (others => '0'); 
			else
			     m_axis_tdata <= s_axis_tdata;
			end if;
			
			m_axis_tlast <= s_axis_tlast;
			s_axis_tready <= m_axis_tready;
			m_axis_tvalid <= s_axis_tvalid;
			
		end if;
	end process;

	
end Behavioral;
