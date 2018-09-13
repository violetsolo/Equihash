----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    15/06/2018 
-- Design Name: 
-- Module Name:    Lg_MultAdd - Behavioral
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

entity Lg_MultAdd is
generic(
	Num			: Natural := 5
);
port (
	Di			: in	typ_1D_Nat(Num-1 downto 0);
	Do			: out	Natural;
	
	clk			: in	std_logic
);
end Lg_MultAdd;

architecture rtl of Lg_MultAdd is
--============================ constant declare ============================--
constant cst_nL			: Natural := Fnc_Int2Wd(Num-1);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_L		: typ_1D_Nat(2**(cst_nL+1)-2 downto 0);

--============================ function declare ============================--

begin

i0200: for i in 0 to Num-1 generate
	sgn_L(i) <= Di(i);
end generate i0200;

t01: if (2**cst_nL /= Num) generate
	i0300: for i in Num to 2**cst_nL-1 generate
		sgn_L(i) <= 0;
	end generate i0300;
end generate t01;

i0100: for i in 0 to cst_nL-1 generate
	i0110: for j in 0 to 2**(cst_nL-1-i)-1 generate
		process(clk)
		begin
			if(rising_edge(clk))then
				sgn_L(j+(2**(cst_nL+1)-2**(cst_nL-i))) <= sgn_L(j*2+(2**(cst_nL+1)-2**(cst_nL-i+1))) + 
														  sgn_L(j*2+1+(2**(cst_nL+1)-2**(cst_nL-i+1)));
			end if;
		end process;
	end generate i0110;
end generate i0100;

Do <= sgn_L(2**(cst_nL+1)-2);

end rtl;
