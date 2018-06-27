----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    22/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UncmpStp5 - Behavioral
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

entity Equihash_GBP_UncmpStp5 is
port (
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	rValid				: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_UncmpStp5;

architecture rtl of Equihash_GBP_UncmpStp5 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Rd);
signal state			: typ_state;

signal sgn_Cnt		: Natural;
--============================ function declare ============================--

begin

Cache_SelRam <= '0'; -- Ai:Bo(0)

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_SelCh <='0';
		rValid <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_Cnt <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					Cache_SelCh <= '1'; -- get cache control right
					state <= S_Rd;
					Bsy <= '1';
				else
					Cache_SelCh <= '0'; -- release cache control right
					Bsy <= '0';
				end if;
			
			when S_Rd =>
				if(sgn_Cnt = gcst_Size_idxCache)then -- 512
					sgn_Cnt <= 0;
					rValid <= '0';
					Ed <= '1';
					state <= S_Idle;
				else
					sgn_Cnt <= sgn_Cnt + 1;
					Cache_A_Rd <= to_unsigned(sgn_Cnt, gcst_WA_idxCache);
					rValid <= '1';
				end if;
			
				
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

