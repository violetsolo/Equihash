----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/06/2018 
-- Design Name: 
-- Module Name:    Lg_SingalPipe - Behavioral
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

entity Lg_SingalPipe is
generic(
	Width_D			: Positive := 8;
	Num_Pipe		: Positive := 10
);
port (
	di		: in	unsigned(Width_D-1 downto 0);
	do		: out	unsigned(Width_D-1 downto 0);
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end Lg_SingalPipe;

architecture rtl of Lg_SingalPipe is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_pp is array (natural range <>) of unsigned(Width_D-1 downto 0);
signal sgn_pp		: typ_pp(Num_Pipe-1 downto 0);
--============================ function declare ============================--

begin

i0100: if(Num_Pipe > 1)generate
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_pp <= (others => (others => '0'));
		elsif(rising_edge(clk))then
			sgn_pp(0) <= di;
			for i in 1 to Num_Pipe-1 loop
				sgn_pp(i) <= sgn_pp(i-1);
			end loop;
		end if;
	end process;
	do <= sgn_pp(Num_Pipe-1);
end generate i0100;

i0200: if(Num_Pipe = 1)generate
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_pp <= (others => (others => '0'));
		elsif(rising_edge(clk))then
			sgn_pp(0) <= di;
		end if;
	end process;
	do <= sgn_pp(Num_Pipe-1);
end generate i0200;

end rtl;
