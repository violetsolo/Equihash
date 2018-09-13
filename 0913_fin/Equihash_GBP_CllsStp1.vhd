----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsStp1 - Behavioral
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

entity Equihash_GBP_CllsStp1 is
port (
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucketRt_Config	: out	std_logic;
	mBucketRt_IncSet	: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_GetSet	: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	mBucket_Init		: out	std_logic;
	mBucket_Rdy			: in	std_logic;
	mBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	IdxMngRst			: out	std_logic;
	LastRound			: out	std_logic;
	
	Mem_AB_Buff_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_AB_Buff_Wr		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	Param_r				: out	Natural range 0 to gcst_Round := 0; -- hold during process
	nxt_St				: out	std_logic;
	nxt_Ed				: in	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_CllsStp1;

architecture rtl of Equihash_GBP_CllsStp1 is
--============================ constant declare ============================--
constant cst_Expo_Round		: Natural := Fnc_Int2Wd(gcst_Round-1);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Config, S_Init, S_InitW, S_nxtSt, S_nxtW);
signal state			: typ_state;

signal sgn_Round		: unsigned(cst_Expo_Round-1 downto 0) := (others => '0');
signal sgn_mBucket_Rdy	: std_logic;
signal sgn_mBucketRt_IncSet	: std_logic;
--============================ function declare ============================--

begin

mBucketRt_IncSet <= sgn_mBucketRt_IncSet;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		mBucketRt_Config <= '0';
		sgn_mBucketRt_IncSet <= '0'; -- Inc channel is B (this module connect to channel B)
		mBucketRt_GetSet <= '1'; -- Get channel is A (this module connect to channel B)
		mBucket_Init <= '0';
		LastRound <= '0';
		IdxMngRst <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_Round <= to_unsigned(0,sgn_Round'length);
		sgn_mBucket_Rdy  <='1';
	elsif(rising_edge(clk))then
		sgn_mBucket_Rdy <= mBucket_Rdy;
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					state <= S_Config;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			when S_Config =>
				mBucketRt_Config	<= '1'; -- config BucketRt
				IdxMngRst <= '1';
				if(sgn_Round = gcst_Round-1)then -- last round 0~8
					mBucket_ChunkSel <= 0; -- no care
					LastRound <= '1'; -- no mbucket inc 
				else
					mBucket_ChunkSel <= to_integer(sgn_Round+1); -- chunk select (point to next chunk)
					LastRound <= '0'; -- mbucket inc enable
				end if;
				sBucket_ChunkSel <= to_integer(sgn_Round);
				if(sgn_Round(0) = '0')then -- even turn src data in A and dst data to B
					sgn_mBucketRt_IncSet	<= '1'; -- Inc data channel is B
					mBucketRt_GetSet		<= '0'; -- GetCnt channel is A
					Mem_AB_Buff_Rd			<= AB_MemD_BaseA;--to_unsigned(AB_Buff_A,gcst_WA_Mem); -- read buff A
					Mem_AB_Buff_Wr			<= AB_MemD_BaseB;--to_unsigned(AB_Buff_B,gcst_WA_Mem); -- write buff B (to mBucket)
				else -- odd turn src data in B and dst data to A
					sgn_mBucketRt_IncSet	<= '0'; -- Inc data channel is A
					mBucketRt_GetSet		<= '1'; -- GetCnt channel is B
					Mem_AB_Buff_Rd			<= AB_MemD_BaseB;--to_unsigned(AB_Buff_B,gcst_WA_Mem); -- read buff B
					Mem_AB_Buff_Wr			<= AB_MemD_BaseA;--to_unsigned(AB_Buff_A,gcst_WA_Mem); -- write buff A (to mBucket)
				end if;
				state <= S_Init;
			
			when S_Init =>
				mBucketRt_Config <= '0';
				IdxMngRst <= '0';
				mBucket_Init <= '1'; -- Init main Bucket couneter
				state <= S_InitW;
			
			when S_InitW =>
				mBucket_Init <= '0';
				if(mBucket_Rdy='1' and sgn_mBucket_Rdy = '0')then -- wait Init process finish (rising edge)
					state <= S_nxtSt;
				end if;
			
			when S_nxtSt =>
				nxt_St <= '1'; -- start next sm
				Param_r <= to_integer(sgn_Round); -- set round for read mem addr calculate
				state <= S_nxtW;
			
			when S_nxtW =>
				nxt_St <= '0';
				if(nxt_Ed='1')then -- wait next sm finish
					if(sgn_Round = gcst_Round-1)then -- last round
						sgn_Round <= to_unsigned(0,sgn_Round'length); -- reset round
						Ed <= '1';
						state <= S_Idle;
					else
						sgn_Round <= sgn_Round + 1; -- round increase
						state <= S_Config;
					end if;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

