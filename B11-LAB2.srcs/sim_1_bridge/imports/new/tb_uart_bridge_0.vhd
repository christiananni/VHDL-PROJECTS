----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.04.2024 17:12:03
-- Design Name: 
-- Module Name: tb_uart_bridge_0 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_uart_bridge_0 is
--  Port ( );
end tb_uart_bridge_0;

architecture Behavioral of tb_uart_bridge_0 is

    component jstk_uart_bridge is
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
    end component;

    constant clk_period : time := 10 ns;           
    constant reset_time : time := 50 ns;

    signal aclk : std_logic := '1';
    signal aresetn : std_logic := '1';

        ----------in-----------
    signal m_axis_tready : std_logic := '0';
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  :  STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); 
    signal jstk_x : std_logic_vector(9 downto 0) := (others => '0');
    signal jstk_y : std_logic_vector(9 downto 0) := (others => '0');
    signal btn_jstk : std_logic := '0';
    signal btn_trigger : std_logic := '0';

    -----------out------------------
    signal m_Axis_tvalid : std_logic := '0';
    
    signal m_axis_tdata : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tready : std_logic := '0';
    
    signal led_r : std_logic_vector(7 downto 0) := (others => '0');
    signal led_g : std_logic_vector(7 downto 0) := (others => '0');
    signal led_b : std_logic_vector(7 downto 0) := (others => '0');

    constant DUT_HEADER : std_logic_vector(7 downto 0) := x"c0";
    constant DUT_DELAY  : integer := 4;
    constant DUT_JSTK_BITS : INTEGER := 7;


begin

    inst_jstk_uart_bridge : jstk_uart_bridge
    generic map(

        HEADER_CODE => DUT_HEADER,
        TX_DELAY => DUT_DELAY,
        JSTK_BITS => DUT_JSTK_BITS

    )
    port map(
        aclk => aclk,
        aresetn => aresetn,

        m_axis_tdata => m_axis_tdata,
        m_axis_tready => m_axis_tready,
        m_axis_tvalid => m_axis_tvalid,

        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,
        s_axis_tready => s_axis_tready,


        jstk_x => jstk_x,			
        jstk_y => jstk_y,			
        btn_jstk => btn_jstk,		
        btn_trigger => btn_trigger,

        led_r => led_r,
        led_g => led_g,
        led_b => led_b
        
    );

    aclk <= not aclk after clk_period/2;

    --------reset-----
    process
    begin
        aresetn <= '0';
        wait for reset_time;
        aresetn <= '1';
        wait;

    end process;

    --------- fpga -> pc -----------

    process
    begin

        wait for reset_time;

        jstk_x <= "0000000000";
        jstk_y <= "0000001111";		
        btn_jstk <= '1';		
        btn_trigger <= '0';

        wait for clk_period*8;

        jstk_x <= "1000000000";
        jstk_y <= "1111111111";		
        btn_jstk <= '0';		
        btn_trigger <= '0';

        wait for clk_period*8;

        jstk_x <= "1100000010";
        jstk_y <= "1100000001";		
        btn_jstk <= '0';		
        btn_trigger <= '1';

        wait for clk_period*8;

        jstk_x <= "0000001000";
        jstk_y <= "0000000001";		
        btn_jstk <= '1';		
        btn_trigger <= '1';

        wait for clk_period*8;

        jstk_x <= "1000000100";
        jstk_y <= "1000000001";		
        btn_jstk <= '1';		
        btn_trigger <= '0';

        wait;

    end process;

    tready : process
    begin
        wait for reset_time;
        wait for clk_period;
        m_axis_tready <= '1';
        wait for clk_period*10;
        m_axis_tready <= '0';
        wait for clk_period*2;
        m_axis_tready <= '1';
        wait;
    end process;

    -----pc->fpga--------

    process
    begin
        wait for reset_time;
        s_axis_tvalid <= '1';

        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"c0";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"12";
        wait for clk_period;
        s_axis_tdata <= x"15";
        wait for clk_period;
        s_axis_tdata <= x"c0";
        wait for clk_period*2;
        s_axis_tdata <= x"20";
        wait for clk_period;
        s_axis_tdata <= x"c0";
        wait for clk_period;
        s_axis_tdata <= x"30";
        wait for clk_period;
        s_axis_tdata <= x"11";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"c0";
        wait for clk_period*2;
        s_axis_tdata <= x"00";
        wait for clk_period;
        s_axis_tdata <= x"10";
        wait for clk_period;
        s_axis_tdata <= x"20";
        wait for clk_period;

        wait;
    end process;
    


end Behavioral;
