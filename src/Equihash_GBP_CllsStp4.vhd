----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_ClsStp4 - Behavioral
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

entity Equihash_GBP_CllsStp4 is
generic(
	sBucket_MaxCap	: Natural := 2**5 -- 17
);
port (
	Mem_Addr_j		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr			: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Addr_j	: out	unsigned(gcst_WA_Cache-1 downto 0); -- hold 2clk every time
	Cache_Idx		: out	unsigned(gcst_WD_Cache_Apdix - 1 downto 0); -- 24bit Accm value and 8bit 0s  -- 1clk delay after Cache_Addr_j output
	Cache_IdxWr		: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	Acc_Clr			: in	std_logic;
	
	IdxReqNum		: out	Natural;
	IdxReq			: out	std_logic;
	IdxAckVal		: in	Natural;
	IdxAck			: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to sBucket_MaxCap;
	
	nxt_St			: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp4;

architecture rtl of Equihash_GBP_CllsStp4 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_GetCnt, S_Rd, S_Wr, S_nxtSt, S_IdxReq);
signal state	: typ_state;

signal sgn_j	: Natural range 0 to sBucket_MaxCap := 0;
signal sgn_Acc	: Natural range 0 to 2**gcst_WD_Cache_Idx-1 := 0; -- 2^24 (3*2^21 actually)
--============================ function declare ============================--

begin

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Mem_Wr <= '0';
		Cache_IdxWr <= '0';
		Cache_Sel <= '0';
		nxt_St <= '0';
		IdxReq <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_j <= 0;
		sgn_Acc <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				nxt_St <= '0';
				Ed <= '0';
				if(St = '1')then
					IdxReq <= '1'; -- require index value
					IdxReqNum <= Param_sBn;
					Cache_Sel <= '1';
					state <= S_IdxReq;
					Bsy <= '1';
				else
					Cache_Sel <= '0';
					Bsy <= '0';
				end if;
			
			when S_IdxReq =>
				-- hold IdxReq until ack arrive
				if(IdxAck = '1')then
					IdxReq <= '0';
					sgn_Acc <= IdxAckVal;
					state <= S_Rd;
				end if;
			
			when S_Rd => -- read idx from cache first
				Cache_IdxWr <= '0';
				if(sgn_j = Param_sBn-1)then -- read finish
					sgn_j <= 0; -- reset sgn_j
					state <= S_nxtSt;
				else
					Cache_Addr_j <= to_unsigned(sgn_j,Cache_Addr_j'length);-- set address outer sgn_j
					Mem_Addr_j <= to_unsigned(sgn_Acc,Mem_Addr_j'length);
					Mem_Wr <= '1'; -- write Mem enable which should delay 6 clk outter for data align
					sgn_j <= sgn_j + 1;
					state <= S_Wr;
				end if;
			
			when S_Wr =>  -- write new index to cache second
--					Cache_Addr_j hold
				Mem_Wr <= '0';
				Cache_Idx(gcst_WD_Cache_Idx-1 downto 0) <= to_unsigned(sgn_Acc,gcst_WD_Cache_Idx);
				Cache_Idx(gcst_WD_Cache_Apdix-1 downto gcst_WD_Cache_Idx) <= (others => '0'); -- setp set to 0
				Cache_IdxWr <= '1'; -- write cache enable
				sgn_Acc <= sgn_Acc + 1; -- Acc increase
				state <= S_Rd;
			
			when S_nxtSt =>
				nxt_St <= '1';
				Ed <= '1';
				state <= S_Idle;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

