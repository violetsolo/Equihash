----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_AddrAuxCalc - Behavioral
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

entity Equihash_AddrAuxCalc is
generic(
	Width_A		: Natural := 32
);
port (
	AB_M			: in	unsigned(Width_A-1 downto 0);
	AB_S			: in	unsigned(Width_A-1 downto 0);
	
	Idx				: in	unsigned(Width_A-1 downto 0);
	Sect			: in	unsigned(Width_A-1 downto 0);
	
	A_o				: out	unsigned(Width_A-1 downto 0);
	
	clk				: in	std_logic
);
end Equihash_AddrAuxCalc;

architecture rtl of Equihash_AddrAuxCalc is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_MultRes		: unsigned(Width_A*2-1 downto 0);
signal sgn_AB_M			: unsigned(Width_A-1 downto 0);
signal sgn_Idx			: unsigned(Width_A-1 downto 0);
--============================ function declare ============================--

begin

process(clk)
begin
	if(rising_edge(clk))then
		sgn_MultRes <= AB_S * Sect;
		sgn_AB_M <= AB_M;
		sgn_Idx <= Idx;
		A_o <= sgn_AB_M + sgn_Idx + sgn_MultRes(Width_A-1 downto 0);
	end if;
end process;

end rtl;

