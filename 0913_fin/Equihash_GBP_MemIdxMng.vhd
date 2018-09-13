----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/08/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_MemIdxMng - Behavioral
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

entity Equihash_GBP_MemIdxMng is
generic(
	Num_Ch		: Natural := 10
);
port (
	DRdy	: in	unsigned(Num_Ch-1 downto 0);
	DRd		: out	unsigned(Num_Ch-1 downto 0);
	Valid	: in	std_logic;
	
	Sel		: out	Natural range 0 to Num_Ch-1;
	
	IdxWr	: out	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end Equihash_GBP_MemIdxMng;

architecture rtl of Equihash_GBP_MemIdxMng is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_pp		: Natural range 0 to Num_Ch-1;
signal sgn_DRd		: unsigned(Num_Ch-1 downto 0);
--============================ function declare ============================--

begin

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_pp <= 0;
		sgn_DRd <= (others => '0');
	elsif(rising_edge(clk))then
		-- robin
		if(sgn_pp = Num_Ch-1)then
			sgn_pp <= 0;
		else
			sgn_pp <= sgn_pp + 1;
		end if;
		-- generate ack accroding to request
		if(DRdy(sgn_pp) = '1' and Valid='1')then
			for i in 0 to Num_Ch-1 loop
				if(i=sgn_pp)then -- 
					sgn_DRd(i) <= '1'; -- set current ack
					Sel <= i;
				else
					sgn_DRd(i) <= '0'; -- clear others ack
				end if;
			end loop;
		else
			sgn_DRd <= (others => '0');
		end if;
	end if;
end process;

IdxWr <= '0' when to_integer(sgn_DRd)=0 else '1'; 
DRd <= sgn_DRd;


end rtl;
