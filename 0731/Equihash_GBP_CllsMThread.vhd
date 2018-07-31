----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsMThread - Behavioral
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

entity Equihash_GBP_CllsMThread is
generic(
	Num_sThread			: Natural := 4;
	mBucket_CntDL		: Natural := 3
);
port (
	mBucketRt_Config	: out	std_logic;
	mBucketRt_IncSet	: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_GetSet	: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_MemChSel	: out	std_logic; -- '0': A->o; '1': B->o
	
	mBucket_Init		: out	std_logic;
	mBucket_Rdy			: in	std_logic;
	mBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	mBucket_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucket_Get			: out	std_logic;
	mBucket_GetIdx		: out	unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	mBucket_Cnt			: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	Param_r				: out	Natural range 0 to gcst_Round := 0;
	LastRound			: out	std_logic;
	Mem_AB_Buff_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1;
	
	Tsk_Param			: out	typ_ThTsk;
	Tsk_Push			: out	unsigned(Num_sThread-1 downto 0);
	sTh_Valid			: in	unsigned(Num_sThread-1 downto 0);
	sTh_Bsy				: in	unsigned(Num_sThread-1 downto 0);
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_CllsMThread;

architecture rtl of Equihash_GBP_CllsMThread is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_GBP_CllsStp1
generic(
	AB_Buff_A		: Natural := gcst_AB_MemA;
	AB_Buff_B		: Natural := gcst_AB_MemB
);
port (
	mBucketRt_Config	: out	std_logic;
	mBucketRt_IncSet	: out	std_logic;
	mBucketRt_GetSet	: out	std_logic;
	mBucketRt_MemChSel	: out	std_logic;
	
	mBucket_Init		: out	std_logic;
	mBucket_Rdy			: in	std_logic;
	mBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	Mem_AB_Buff_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_AB_Buff_Wr		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	IdxMngRst			: out	std_logic;
	LastRound			: out	std_logic;
	
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
end component;

component Equihash_GBP_CllsTskGen
generic(
	mBucket_CntDL	: Natural := mBucket_CntDL
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
end component;

component Equihash_GBP_CllsSDisp
generic(
	Num_sThread		: Natural := Num_sThread
);
port (
	Param_q			: out	Natural range 0 to gcst_mBucket_Num-1;
	mBn				: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	sTh_Valid		: in	unsigned(Num_sThread-1 downto 0);
	sTh_Bsy			: in	unsigned(Num_sThread-1 downto 0);
	Tsk_Push		: out	unsigned(Num_sThread-1 downto 0);
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	TskGen_St		: out	std_logic;
	TskGen_Ed		: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

--============================= signal declare =============================--
-- st and end chain
signal sgn_St_Stp1_sThD			: std_logic;
signal sgn_St_sThD_TG			: std_logic;

signal sgn_Ed_TG_sThD			: std_logic;
signal sgn_Ed_sThD_Stp1			: std_logic;

-- param
-- from stp1
signal sgn_r					: Natural range 0 to gcst_Round;
-- from stp2
signal sgn_q					: Natural range 0 to gcst_mBucket_Num-1;
signal sgn_mBn					: Natural range 0 to gcst_mBucket_MaxCap;
signal sgn_IdxMngRst			: std_logic;

-- delay

--============================ function declare ============================--

begin

inst01: Equihash_GBP_CllsStp1
port map(
	mBucketRt_Config	=> mBucketRt_Config,--(IO): out	std_logic;
	mBucketRt_IncSet	=> mBucketRt_IncSet,--(IO): out	std_logic;
	mBucketRt_GetSet	=> mBucketRt_GetSet,--(IO): out	std_logic;
	mBucketRt_MemChSel	=> mBucketRt_MemChSel,--: out	std_logic;
	
	mBucket_Init		=> mBucket_Init,--(IO): out	std_logic;
	mBucket_Rdy			=> mBucket_Rdy,--(IO): in	std_logic;
	mBucket_ChunkSel	=> mBucket_ChunkSel,--(IO): out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	IdxMngRst			=> sgn_IdxMngRst,--: out	std_logic;
	LastRound			=> LastRound,--(IO): out	std_logic;
	
	Mem_AB_Buff_Rd		=> Mem_AB_Buff_Rd,--(IO): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_AB_Buff_Wr		=> mBucket_AB_Buff,--(IO): out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	=> sBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	St					=> St,--(IO): in	std_logic;
	Ed					=> Ed,--(IO): out	std_logic;
	Bsy					=> open,--(IO): out	std_logic;
	
	Param_r				=> Param_r,--(IO): out	Natural range 0 to gcst_Round-1 := 0; -- hold during process
	nxt_St				=> sgn_St_Stp1_sThD,--: out	std_logic;
	nxt_Ed				=> sgn_Ed_sThD_Stp1,--: in	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

inst02: Equihash_GBP_CllsTskGen
port map(
	mBucket_Get		=> mBucket_Get,--(IO): out	std_logic;
	mBucket_Cnt		=> mBucket_Cnt,--(IO): in	Natural range 0 to gcst_mBucket_MaxCap;
	
	AB_MemIdxRst	=> sgn_IdxMngRst,--: in	std_logic;
	
	mBn				=> sgn_mBn,--: out	Natural range 0 to gcst_mBucket_MaxCap;
	AB_IdxArr_Sub	=> Tsk_Param.AB_IdxArrSub,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	St				=> sgn_St_sThD_TG,--: in	std_logic;
	Ed				=> sgn_Ed_TG_sThD,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

mBucket_GetIdx <= to_unsigned(sgn_q, gcst_W_Chunk);

Tsk_Param.Param_q <= sgn_q;
Tsk_Param.mBn <= sgn_mBn;

inst03: Equihash_GBP_CllsSDisp
port map(
	Param_q			=> sgn_q,--: out	Natural range 0 to gcst_mBucket_Num-1;
	mBn				=> sgn_mBn,--: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	sTh_Valid		=> sTh_Valid,--(io): in	unsigned(Num_sThread-1 downto 0);
	sTh_Bsy			=> sTh_Bsy,--(io): in	unsigned(Num_sThread-1 downto 0);
	Tsk_Push		=> Tsk_Push,--(io): out	unsigned(Num_sThread-1 downto 0);
	
	St				=> sgn_St_Stp1_sThD,--: in	std_logic;
	Ed				=> sgn_Ed_sThD_Stp1,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	TskGen_St		=> sgn_St_sThD_TG,--: out	std_logic;
	TskGen_Ed		=> sgn_Ed_TG_sThD,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- delay

end rtl;

