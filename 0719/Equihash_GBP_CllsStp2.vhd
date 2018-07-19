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
generic(
	mBucket_CntSumDL	: Natural := 3
);
port (
	mBucket_Get		: out	std_logic;
	mBucket_Cnt		: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	Mem_Addr_i		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			: out	std_logic;
	Mem_RdBsy		: in	std_logic;
	
	AB_RamIdx		: out	unsigned(gcst_WA_Mem-1 downto 0);
	AB_RamIdxRst	: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	pQuit			: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp2;

architecture rtl of Equihash_GBP_CllsStp2 is
--============================ constant declare ============================--
constant cst_GetW_DL		: Natural := gcst_BucketDisp_RtlDL_Get + -- Dispatch delay
										 gcst_BucketRt2x2_RtlDL + -- push get
										 gcst_BucketRt2x2_RtlDL + -- return value
										 mBucket_CntSumDL; 
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_GetCnt, S_GetW, S_preRd, S_MemRd, S_RdQuit);
signal state			: typ_state;

signal sgn_GetW_Cnt		: Natural range 0 to cst_GetW_DL+1 := 0;

signal sgn_mBn			: Natural range 0 to gcst_mBucket_MaxCap := 0; -- store bucket counter number returned
signal sgn_i			: Natural range 0 to gcst_mBucket_MaxCap := 0;
signal sgn_Mem_RdBsy	: std_logic;

signal sgn_Acc			: Natural range 0 to gcst_AB_MemIdx_Sect;
signal sgn_AccInc		: std_logic;
--============================ function declare ============================--

begin
-- ram idx ab acc
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Acc <= 0;
	elsif(rising_edge(clk))then
		if(AB_RamIdxRst='1')then
			sgn_Acc <= 0;
		elsif(sgn_AccInc = '1')then
			sgn_Acc <= sgn_Acc + sgn_mBn;
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		mBucket_Get <= '0';
		Mem_Rd <= '0';
		nxt_St <= '0';
		pQuit <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_GetW_Cnt <= 0;
		sgn_Mem_RdBsy <= '0';
		sgn_AccInc <= '0';
	elsif(rising_edge(clk))then
		sgn_Mem_RdBsy <= Mem_RdBsy;
		case state is
			when S_Idle =>
				Ed <= '0';
				pQuit <= '0';
				nxt_St <= '0';
				sgn_AccInc <= '0';
				if(St = '1')then
					state <= S_GetCnt;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_GetCnt =>
				mBucket_Get <= '1'; -- get bucket counter
--					sgn_GetIdx -- bucket index is sgn_q ready by task_dispatch
				sgn_GetW_Cnt <= 0; -- reset wait counter
				state <= S_GetW;
			
			when S_GetW =>
				mBucket_Get <= '0';
				sgn_GetW_Cnt <= sgn_GetW_Cnt + 1; -- wait counter increase
				if(sgn_GetW_Cnt = cst_GetW_DL)then -- bucket module delay
					state <= S_preRd;
					sgn_mBn <= mBucket_Cnt; -- save bucket counter
				end if;
			
			when S_preRd =>
				if(sgn_mBn <= 1)then -- less than 1 element
					Ed <= '1';
					pQuit <= '1';
					state <= S_Idle;-- finish this loop
				else
					sgn_i <= 0; -- reset sgn_i
					state <= S_MemRd;
				end if;
			
			when S_MemRd => -- read data
				if(sgn_i = sgn_mBn)then -- read data finish
					Mem_Rd <= '0'; -- read disable
					state <= S_RdQuit;
				else
					Mem_Addr_i <= to_unsigned(sgn_i, Mem_Addr_i'length); -- set sgn_i to outter
					sgn_i <= sgn_i + 1; -- sgn_i increase
					Mem_Rd <= '1'; -- read enable
					state <= S_MemRd;
				end if;
			
			when S_RdQuit => -- wait for data read finish
				if(Mem_RdBsy='0' and sgn_Mem_RdBsy = '1')then -- falling edge
					AB_RamIdx <= to_unsigned(sgn_Acc,gcst_WA_Mem); -- send out current acc value
					sgn_AccInc <= '1'; -- Acc increase
					nxt_St <= '1';-- start next sm
					Ed <= '1';
					state <= S_Idle;
				end if;
				
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

