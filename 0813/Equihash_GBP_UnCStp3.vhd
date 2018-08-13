----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    19/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UncmpStp3 - Behavioral
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

entity Equihash_GBP_UncmpStp3 is
port (
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	CmpRes				: in	std_logic;
	CmpRes_Rst			: out	std_logic;
	CmpRes_L			: out	std_logic;
	
	mVal_L				: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	pQit				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_UncmpStp3;

architecture rtl of Equihash_GBP_UncmpStp3 is
--============================ constant declare ============================--
constant cst_RamRdDL		: Natural := gcst_IdxCache_RtlDL_Rd;
constant cst_CmpResDL		: Natural := cst_RamRdDL + 1; -- 1 cpmpare
constant cst_RoundMax		: Natural := gcst_Size_idxCache-1; -- 511
constant cst_IdxCntMax		: Natural := gcst_Size_idxCache; -- 512

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_mRd, S_mRdW, S_sRd, S_sRdW, S_Cmp);
signal state			: typ_state;

signal sgn_mCnt		: Natural range 0 to cst_RoundMax-1;-- 0~510
signal sgn_sCnt		: Natural range 0 to cst_IdxCntMax;-- m~512

signal sgn_wCnt		: Natural;
--============================ function declare ============================--

begin

Cache_SelRam <= '1'; -- always Ao:Bi(1)

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_SelCh <= '0';
		CmpRes_Rst <= '0';
		CmpRes_L <= '0';
		mVal_L <= '0';
		pQit <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_mCnt <= 0;
		sgn_sCnt <= 0;
		sgn_wCnt <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				nxt_St <= '0';
				pQit <= '0';
				if(St = '1')then
					Cache_SelCh <= '1';
					state <= S_mRd;
					Bsy <= '1';
				else
					Cache_SelCh <= '0';
					Bsy <= '0';
				end if;
			
			when S_mRd => -- get first data
				Cache_A_Rd <= to_unsigned(sgn_mCnt, gcst_WA_idxCache);
				mVal_L <= '1'; -- should delay outside
				CmpRes_Rst <= '1'; -- reset compare result
				state <= S_mRdW;
			
			when S_mRdW => -- wait for data latch
				mVal_L <= '0';
				CmpRes_Rst <= '0';
				sgn_wCnt <= sgn_wCnt + 1;
				if(sgn_wCnt = cst_RamRdDL-1)then
					sgn_wCnt <= 0;
					sgn_sCnt <= sgn_mCnt + 1; -- s = m + 1 (next value)
					state <= S_sRd;
				end if;
			
			when S_sRd => -- get all second data
				if(sgn_sCnt = cst_IdxCntMax)then -- to the last value counter is 512
					CmpRes_L <= '0';
					state <= S_sRdW;
				else
					sgn_sCnt <= sgn_sCnt + 1;
					Cache_A_Rd <= to_unsigned(sgn_sCnt, gcst_WA_idxCache);
					CmpRes_L <= '1'; -- record cmp result
				end if;
			
			when S_sRdW => -- wait last data compare finish
				sgn_wCnt <= sgn_wCnt + 1;
				if(sgn_wCnt = cst_CmpResDL-1)then
					sgn_wCnt <= 0;
					state <= S_Cmp;
				end if;
			
			when S_Cmp =>
				if(CmpRes = '1')then -- some data are equal
					pQit <= '1'; -- quit progress
					Ed <= '1';
					sgn_mCnt <= 0; -- m reset
					state <= S_Idle;
				else
					if(sgn_mCnt = cst_RoundMax-1)then -- last round
						sgn_mCnt <= 0; -- m reset
						Ed <= '1';
						nxt_St <= '1';
						state <= S_Idle;
					else
						sgn_mCnt <= sgn_mCnt + 1; -- m increase
						state <= S_mRd;
					end if;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

