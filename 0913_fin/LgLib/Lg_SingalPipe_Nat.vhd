----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/06/2018 
-- Design Name: 
-- Module Name:    Lg_SingalPipe_Nat - Behavioral
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

entity Lg_SingalPipe_Nat is
generic(
	Num_Pipe		: Positive := 10
);
port (
	di		: in	Natural;
	do		: out	Natural;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end Lg_SingalPipe_Nat;

architecture rtl of Lg_SingalPipe_Nat is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_pp is array (natural range <>) of Natural;
signal sgn_pp		: typ_pp(Num_Pipe-1 downto 0);
--============================ function declare ============================--

begin

i0100: if(Num_Pipe > 1)generate
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_pp <= (others => 0);
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
			sgn_pp <= (others => 0);
		elsif(rising_edge(clk))then
			sgn_pp(0) <= di;
		end if;
	end process;
	do <= sgn_pp(Num_Pipe-1);
end generate i0200;

i0300: if(Num_Pipe = 0)generate
	do <= di;
end generate i0300;

end rtl;
