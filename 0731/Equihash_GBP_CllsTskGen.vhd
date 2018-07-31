----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsTskGen - Behavioral
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

entity Equihash_GBP_CllsTskGen is
generic(
	mBucket_CntDL	: Natural := 3
);
port (
	mBucket_Get		: out	std_logic;
	mBucket_Cnt		: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	AB_MemIdxRst	: in	std_logic;
	
	mBn				: out	Natural range 0 to gcst_mBucket_MaxCap;
	AB_IdxArr_Sub	: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsTskGen;

architecture rtl of Equihash_GBP_CllsTskGen is
--============================ constant declare ============================--
constant cst_GetW_DL		: Natural := gcst_BucketDisp_RtlDL_Get + -- Dispatch delay
										 gcst_BucketRt2x2_RtlDL + -- push get
										 gcst_BucketRt2x2_RtlDL + -- return value
										 mBucket_CntDL; 
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_GetW);
signal state			: typ_state;

signal sgn_GetW_Cnt		: Natural range 0 to cst_GetW_DL+1 := 0;

signal sgn_mBn			: Natural  range 0 to gcst_mBucket_MaxCap;
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
		if(AB_MemIdxRst='1')then
			sgn_Acc <= 0;
		elsif(sgn_AccInc = '1')then
			sgn_Acc <= sgn_Acc + sgn_mBn; -- ready for next task
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		mBucket_Get <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_GetW_Cnt <= 0;
		sgn_AccInc <= '0';
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				sgn_AccInc <= '0';
				sgn_GetW_Cnt <= 0; -- reset wait counter
				if(St = '1')then
--					mBucket_GetIdx -- bucket index is sgn_q ready by task_dispatch
					mBucket_Get <= '1'; -- get bucket counter
					Bsy <= '1';
					state <= S_GetW;
				else
					Bsy <= '0';
				end if;
			
			when S_GetW =>
				mBucket_Get <= '0';
				sgn_GetW_Cnt <= sgn_GetW_Cnt + 1; -- wait counter increase
				if(sgn_GetW_Cnt = cst_GetW_DL)then -- bucket module delay
					sgn_mBn <= mBucket_Cnt;
					AB_IdxArr_Sub <= to_unsigned(sgn_Acc,gcst_WA_Mem);
					Ed <= '1';
					sgn_AccInc <= '1';
					state <= S_Idle;
				end if;
				
			when others => State <= S_Idle;
		end case;
	end if;
end process;

mBn <= sgn_mBn;

end rtl;

