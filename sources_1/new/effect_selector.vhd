library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity effect_selector is
    generic(
        JSTK_BITS  : integer := 10
    );
    Port (
        aclk 		: in STD_LOGIC;
        aresetn		: in STD_LOGIC;
        effect		: in STD_LOGIC; 
        jstck_x		: in STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0); --balance
        jstck_y		: in STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0); --volume o LFO
        volume		: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        balance		: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        jstk_y_lfo	: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0) --LFO period
    );
end effect_selector;

architecture Behavioral of effect_selector is

begin
    process(aresetn, aclk)
    begin
        if aresetn = '0' then
            --resetta tutto ai valori medi (512)
            volume <= std_logic_vector(to_unsigned((2 **(JSTK_BITS - 1)), JSTK_BITS));
            balance <= std_logic_vector(to_unsigned((2 **(JSTK_BITS - 1)), JSTK_BITS));
            jstk_y_lfo <= std_logic_vector(to_unsigned((2 **(JSTK_BITS - 1)), JSTK_BITS));

        elsif rising_edge(aclk) then
        
            if effect = '0' then

                volume <= jstck_y;
                balance <= jstck_x;

            else

                jstk_y_lfo <= jstck_y;

            end if;
            
        end if;
    end process;


end Behavioral;
