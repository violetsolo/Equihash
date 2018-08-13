----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    16/07/2018 
-- Design Name: 
-- Module Name:    Lg_Robin_TypI - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.LgGlobal_pkg.all;
use work.Equihash_pkg.all;

entity Lg_Robin_TypI is
generic(
	Robin_Num		: Natural := 4
);
port (
	Req				: in	unsigned(Robin_Num-1 downto 0);
	Ack				: out	unsigned(Robin_Num-1 downto 0);
	
	Sel				: out	Natural range 0 to Robin_Num-1;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Lg_Robin_TypI;

architecture rtl of Lg_Robin_TypI is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_RobinCnt		: Natural range 0 to Robin_Num-1;
--============================ function declare ============================--

begin

process(aclr,clk)
begin
	if(aclr='1')then
		Ack <= (others => '0');
		Sel <= 0;
		-- signal
		sgn_RobinCnt <= 0;
	elsif(rising_edge(clk))then
		Sel <= sgn_RobinCnt;
		if(Req(sgn_RobinCnt)='1')then
			for i in 0 to Robin_Num-1 loop
				if(i=sgn_RobinCnt)then
					Ack(i) <= '1';
				else
					Ack(i) <= '0';
				end if;
			end loop;
		else
			Ack <= (others => '0');
		end if;
		if(sgn_RobinCnt=Robin_Num-1)then
			sgn_RobinCnt <= 0;
		else
			sgn_RobinCnt <= sgn_RobinCnt + 1;
		end if;
	end if;
end process;

end rtl;

