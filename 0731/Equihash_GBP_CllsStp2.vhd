----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsStp2 - Behavioral
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

entity Equihash_GBP_CllsStp2 is
port (
	mBn				: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	FIFO_Rd			: out	std_logic;
	FIFO_Emp		: in	std_logic;
	
	Mem_Addr_i		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			: out	std_logic;
	Mem_RdBsy		: in	std_logic;
	
	AccRst			: out	std_logic;
	
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp2;

architecture rtl of Equihash_GBP_CllsStp2 is
--============================ constant declare ============================--
 
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_W, S_MemRd, S_RdW, S_TskW);
signal state			: typ_state;

signal sgn_i			: Natural range 0 to gcst_mBucket_MaxCap := 0;
signal sgn_Mem_RdBsy	: std_logic;

--============================ function declare ============================--

begin
process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		FIFO_Rd <= '0';
		Mem_Rd <= '0';
		AccRst <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_Mem_RdBsy <= '0';
		sgn_i <= 0;
	elsif(rising_edge(clk))then
		sgn_Mem_RdBsy <= Mem_RdBsy;
		case state is
			when S_Idle =>
				Ed <= '0';
				nxt_St <= '0';
				if(FIFO_Emp = '0')then -- at least 1 task in fifo
					state <= S_W;
					FIFO_Rd <= '1'; -- read fifo
					AccRst <= '1';
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_W => -- wait 1 clk
				AccRst <= '0';
				FIFO_Rd <= '0';
				state <= S_MemRd; -- mBn always is lager than 1
			
			when S_MemRd => -- read data
				if(sgn_i = mBn)then -- read data finish
					Mem_Rd <= '0'; -- read disable
					sgn_i <= 0;
					state <= S_RdW;
				else
					Mem_Addr_i <= to_unsigned(sgn_i, Mem_Addr_i'length); -- set sgn_i to outter
					sgn_i <= sgn_i + 1; -- sgn_i increase
					Mem_Rd <= '1'; -- read enable
				end if;
			
			when S_RdW => -- wait for data read finish
				if(Mem_RdBsy='0' and sgn_Mem_RdBsy = '1')then -- falling edge
					nxt_St <= '1';-- start next step
					state <= S_TskW;
				end if;
			
			when S_TskW =>
				nxt_St <= '0';
				if(nxt_Ed='1')then -- wait for next state finish
					Ed <= '1';
					state <= S_Idle;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

