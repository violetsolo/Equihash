----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/08/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsTskPush - Behavioral
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

entity Equihash_GBP_CllsTskPush is
generic(
	mBucket_CntDL	: Natural := 3;
	Num_mBSect		: Natural := 4
);
port (
	mBucket_Get		: out	std_logic;
	mBucket_GetIdx	: out	unsigned(gcst_W_Chunk-1 downto 0);
	mBucket_Cnt		: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	Tsk_Param		: out	typ_ThTsk;
	Tsk_Push		: out	std_logic;
	Tsk_Valid		: in	std_logic;
	Tsk_Bsy			: in	std_logic;
	
	MemIdx_Req		: out	std_logic;
	MemIdx_Num		: out	Natural range 0 to gcst_mBucket_MaxCap;
	MemIdx_Ack		: in	std_logic;
	MemIdx_Sub		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsTskPush;

architecture rtl of Equihash_GBP_CllsTskPush is
--============================ constant declare ============================--
constant cst_GetW_DL		: Natural := gcst_BucketDisp_RtlDL_Get + -- Dispatch delay
										 gcst_BucketRt2x2_RtlDL + -- push get
										 gcst_BucketRt2x2_RtlDL + -- return value
										 mBucket_CntDL; 
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_GetCntW, S_GetIdxW, S_ValidW, S_Fin, S_ThW);
signal state			: typ_state;

signal sgn_GetWCnt		: Natural;-- range 0 to cst_GetW_DL+1;
signal sgn_mBn			: Natural  range 0 to gcst_mBucket_MaxCap;
signal sgn_q			: Natural range 0 to Num_mBSect;

--============================ function declare ============================--

begin

mBucket_GetIdx <= to_unsigned(sgn_q, gcst_W_Chunk);
Tsk_Param.mBn <= sgn_mBn;
Tsk_Param.Param_q <= sgn_q;
--Tsk_Param.AB_IdxArrSub <= MemIdx_Sub;

process(clk,aclr)
begin
	if(aclr='1')then
		-- io
		mBucket_Get <= '0';
		Tsk_Push <= '0';
		MemIdx_Req <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		state <= S_Idle;
		sgn_GetWCnt <= 0;
		sgn_q <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				sgn_GetWCnt <= 0;
				Ed <= '0';
				if(St='1')then
					mBucket_Get <= '1';
					Bsy <= '1';
					state <= S_GetCntW;
				else
					Bsy <= '0';
				end if;
			
			when S_GetCntW =>
				mBucket_Get <= '0';
				sgn_GetWCnt <= sgn_GetWCnt + 1;
				if(sgn_GetWCnt=cst_GetW_DL)then
					sgn_mBn <= mBucket_Cnt;
					MemIdx_Num <= mBucket_Cnt;
					if(mBucket_Cnt=0)then -- no data in bucket
						state <= S_Fin;
					else
						state <= S_GetIdxW;
						MemIdx_Req <= '1'; -- should be hold
					end if;
				end if;
			
			when S_GetIdxW =>
				sgn_GetWCnt <= 0;
				if(MemIdx_Ack='1')then -- 
					MemIdx_Req <= '0';
					Tsk_Param.AB_IdxArrSub <= MemIdx_Sub;
					if(Tsk_Valid='1')then
						Tsk_Push <= '1';
						state <= S_Fin;
					else
						state <= S_ValidW;
					end if;
				end if;
			
			when S_ValidW => 
				if(Tsk_Valid='1')then
					Tsk_Push <= '1';
					state <= S_Fin;
				end if;
			
			when S_Fin =>
				sgn_GetWCnt <= 0;
				Tsk_Push <= '0';
				if(sgn_q = Num_mBSect-1)then
					sgn_q <= 0;
					state <= S_ThW;
				else
					sgn_q <= sgn_q + 1;
					mBucket_Get <= '1';
					state <= S_GetCntW;
				end if;
			
			when S_ThW =>
				if(Tsk_Bsy='0')then
					Ed <= '1';
					state <= S_Idle;
				end if;
			
			when others => state <= S_Idle;
		
		end case;
		
	end if;
end process;


end rtl;

