----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.04.2024 14:03:49
-- Design Name: 
-- Module Name: tb_digilent_jstk2 - Behavioral
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

entity tb_digilent_jstk2 is
--  Port ( );
end tb_digilent_jstk2;

architecture Behavioral of tb_digilent_jstk2 is
    --in--
    signal aclk : std_logic := '1';
    signal aresetn : std_logic := '1';

    signal m_axis_tready : std_Logic := '0';
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');

    signal led_r : std_logic_vector(7 downto 0) := (others => '0');
    signal led_g : std_logic_vector(7 downto 0) := (others => '0');
    signal led_b : std_logic_vector(7 downto 0) := (others => '0');

    --out--
    signal m_axis_tdata : std_logic_vector(7 downto 0) := (others => '0');
    signal m_axis_tvalid : std_logic := '0';

    signal jstk_x : std_logic_vector(9 downto 0);
    signal jstk_y : std_logic_vector(9 downto 0);
    signal btn_jstk : std_logic;    
    signal btn_trigger : std_logic;

    constant clk_period : time := 10 ns;           
    constant reset_time : time := 50 ns;


    component digilent_jstk2 is
        generic (
            DELAY_US		: integer := 25;    -- Delay (in us) between two packets
            CLKFREQ		 	: integer := 10_000_000;  -- Frequency of the aclk signal (in Hz)               I
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
    end component;

begin



    inst_jstk2 : digilent_jstk2
    generic map(

        DELAY_US =>	1,	
        CLKFREQ	=>	3,	        ---- modificati per rendere più leggibile la simulazione
        SPI_SCLKFREQ => 1	    ---- cambiando clkfreq cambia il numero di periodi di clk da aspettare dopo la trasmissione, CLKFREQ == NUMEROPERIODI,
                                ---- ovviamente questo vale solo in simulazione

    )
    port map(

        aclk => aclk,
        aresetn => aresetn,

        m_axis_tvalid => m_axis_tvalid,
        m_axis_tdata => m_axis_tdata,
        m_axis_tready => m_axis_tready,

        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,

        jstk_x => jstk_x,
        jstk_y => jstk_y,
        btn_jstk => btn_jstk,
        btn_trigger => btn_trigger,

        led_r => led_r,
        led_g => led_g,
        led_b => led_b
    );

    ---------------CLOCK-------------------

    aclk <= not aclk after clk_period/2;

    ----------------PROCESS PER IL RESET---------------------

    process_reset : process 
    begin

        aresetn <= '0';
        wait for reset_time;
        aresetn <= '1';
        wait for clk_period*30;
        aresetn <= '0';
        wait for clk_period;
        aresetn <= '1';
        wait; 

    end process;

    --------------PROCESS PER DEFINIRE I VALORI DEL COLORE, SAREBBERO I VALORI CHE IL MODULO_SPI_FPGA RICEVE DAL MODULO_PC_FPGA

    process_led : process
        
    begin
        wait for reset_time;
        
        led_r <= "00000001";
        led_g <= "00000010";
        led_b <= "00000100";

        wait for clk_period*10;

        led_r <= "00000011";
        led_g <= "00000110";
        led_b <= "00001100";

        wait for clk_period*10;

        led_r <= "00000101";
        led_g <= "00001010";
        led_b <= "00010100";

        wait for clk_period*10;
        
        wait;

    end process;

    -----------PPROCESS VALORI AXIS SLAVE, VALORI MANDATI DAL SPI E RICEVUTI DAL MODULO------------------

    process_axis_ricezione : process
    begin
        wait for reset_time;
        wait for clk_period*3;

        s_axis_tdata <= "00000001"; -- X LOW
        s_axis_tvalid <= '1';
        wait for clk_period;
        s_axis_tvalid <= '0';
        wait for clk_period*2;

        s_axis_tdata <= "00000010"; -- X HIGH
        s_axis_tvalid <= '1';
        wait for clk_period;
        s_axis_tvalid <= '0';
        wait for clk_period*3;

        s_axis_tdata <= "00000100"; -- Y LOW
        s_axis_tvalid <= '1';
        wait for clk_period;
        s_axis_tvalid <= '0';
        wait for clk_period;

        s_axis_tdata <= "00001010"; -- Y HIGH
        s_axis_tvalid <= '1';
        wait for clk_period;
        s_axis_tvalid <= '0';
        wait for clk_period*7;

        s_axis_tdata <= "00010111"; --UNLTIMI 2 BIT DESCRIVONO I BOTTONI
        s_axis_tvalid <= '1';
        wait for clk_period;
        s_axis_tvalid <= '0';
        

        wait;

    end process;

    -------------------PROCESS AXIS MASTER, DEFINISCE QUANDO IL JSTK E' READY(PRONTO A RICEVERE)---------------------------------------

--    process_axis_invio : process(aclk)  --- gestisco tready ovvero se il jstk è pronto, suppongo per semplificare la simulazione che sia periodico (dovrebbe funzionare anche se non periodico)
--    begin                               ---il tready rimane alto un solo periodo.
--        
--
--       if rising_edge(aclk)  then
--           m_axis_tready <= not m_axis_tready;
--       end if;
--
--       --m_axis_tready <= '1'; ---CASO TREADY SEMPRE ALTO, IL FUNZIONAMENTO DEL MODULO IN QUESTO CASO DOVREBBE ESSERE CORRETTO, CONTROLLATE.
--        
--        
--    end process;

    process_axis_invio2 : process
    begin

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        m_axis_tready <= not m_axis_tready;
        wait for clk_period*2;

        wait;

    end process;


    


end Behavioral;