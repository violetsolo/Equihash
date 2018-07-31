-- Quartus Prime VHDL Template
-- Simple Dual-Port RAM with different read/write addresses but
-- single read/write clock

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Lg_DP_Ram_Sc is
generic (
	Data_Width : natural := 8;
	Data_Num 	: natural := 6
);
port (
	data	: in unsigned((Data_Width-1) downto 0);
	waddr	: in natural range 0 to Data_Num - 1;
	we		: in std_logic := '1';
	
	q		: out unsigned((Data_Width -1) downto 0);
	raddr	: in natural range 0 to Data_Num - 1;
	
	clk		: in std_logic
);
end Lg_DP_Ram_Sc;

architecture rtl of Lg_DP_Ram_Sc is

	-- Build a 2-D array type for the RAM
	subtype word_t is unsigned((Data_Width-1) downto 0);
	type memory_t is array(Data_Num-1 downto 0) of word_t;

	-- Declare the RAM signal.	
	signal ram : memory_t;

begin

	process(clk)
	begin
	if(rising_edge(clk)) then 
		if(we = '1') then
			ram(waddr) <= data;
		end if;
 
		-- On a read during a write to the same address, the read will
		-- return the OLD data at the address
		q <= ram(raddr);
	end if;
	end process;

end rtl;