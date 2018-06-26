----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    15/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_Wrapper - Behavioral
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

entity Equihash_GBP_Wrapper is
generic(
	Device_Family		: string := "Cyclone V";
	mBucket_Width		: Natural := 12;
	mBucket_Offset		: Natural := 0;
	mBucket_Num			: Natural := 2**12;
	mBucket_MaxCap		: Natural := 3*2**9;--2**11; -- 3*2**9
	sBucket_Width		: Natural := 8;
	sBucket_Offset		: Natural := 12;
	sBucket_Num			: Natural := 2**8;
	sBucket_MaxCap		: Natural := 17;--2**5 -- 17
	Num_sThread			: Natural := 1
);
port (
	-- Bucket router config
	BucketRt_Config		: in	std_logic; -- high priority
	BucketRt_IncSet		: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	: in	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			: in	std_logic;
	Bucket_Rdy			: out	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	-- Bucket data input and counter increase
	Bucket_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	Bucket_Inc			: in	std_logic;
	-- read data from buffer (memory)
	Mem_p1_A			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p1_Rd			: out	std_logic;
	Mem_p1_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_p1_RdAck		: in	std_logic;
	-- write index info into memory
	Mem_p2_A			: out	typ_1D_MemApdix_A(Num_sThread-1 downto 0);
	Mem_p2_Do			: out	typ_1D_MemApdix_D(Num_sThread-1 downto 0);
	Mem_p2_Wr			: out	unsigned(Num_sThread-1 downto 0);
	-- write data into memory
	Mem_p3_A			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_p3_Do			: out	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_p3_Wr			: out	unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
	Mem_p4_A			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p4_Rd			: out	std_logic;
	Mem_p4_Di			: in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_p4_RdAck		: in	std_logic;
	-- result
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_Idx-1 downto 0);
	-- GBP process strat
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Equihash_GBP_Wrapper;

architecture rtl of Equihash_GBP_Wrapper is
--============================ constant declare ============================--
constant cst_mBucket_CntSumDL	: Natural := Fnc_Int2Wd(Num_sThread-1);
constant cst_AB_IdxArr_M		: unsigned(gcst_WA_Mem-1 downto 0) := to_unsigned(mBucket_MaxCap*mBucket_Num*2,gcst_WA_Mem);
constant cst_AB_IdxArr_Sect		: unsigned(gcst_WA_Mem-1 downto 0) := to_unsigned(mBucket_MaxCap,gcst_WA_Mem);

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_GBP_CllsMThread
generic(
	mBucket_Width		: Natural := mBucket_Width;
	mBucket_Offset		: Natural := mBucket_Offset;
	mBucket_Num			: Natural := mBucket_Num;
	mBucket_MaxCap		: Natural := mBucket_MaxCap;--2**11; -- 3*2**9
	Num_sThread			: Natural := Num_sThread;
	mBucket_CntSumDL	: Natural := cst_mBucket_CntSumDL -- log2(Num_sThread)
);
port (
	mBucketRt_Config			: out	std_logic;
	mBucketRt_IncSet			: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_GetSet			: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_MemChSel			: out	std_logic; -- '0': A->o; '1': B->o
	
	mBucket_Init				: out	std_logic;
	mBucket_Rdy					: in	std_logic;
	mBucket_ChunkSel			: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	mBucket_AB_Buff				: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucket_Get					: out	std_logic;
	mBucket_GetIdx				: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	mBucket_Cnt					: in	Natural range 0 to mBucket_MaxCap;
	
	IdxMngRst					: out	std_logic;
	LastRound					: out std_logic;
	
	sBucket_ChunkSel			: out	Natural range 0 to gcst_N_Chunk-1;

	Mem_Addr					: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd						: out	std_logic;
	Mem_RdAck					: in	std_logic;
	
	Param_r						: out	Natural range 0 to gcst_Round-1 := 0;
	
	sThread_Sel					: out Natural range 0 to Num_sThread-1;
	sThread_Ed					: in	unsigned(Num_sThread-1 downto 0);
	sThread_St					: out	std_logic;
	
	St							: in	std_logic;
	Ed							: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_CllsSThread
generic(
	Device_Family		: string := Device_Family;
	mBucket_Num			: Natural := mBucket_Num;
	mBucket_MaxCap		: Natural := mBucket_MaxCap; -- 3*2**9
	sBucket_Width		: Natural := sBucket_Width;
	sBucket_Offset		: Natural := sBucket_Offset;
	sBucket_Num			: Natural := sBucket_Num;
	sBucket_MaxCap		: Natural := sBucket_MaxCap--2**5 -- 17
);
port (
	sBucket_ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	
	sBucket_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	sBucket_Inc			: in	std_logic;
	
	mBucket_Di			: out unsigned(gcst_WD_Mem-1 downto 0);
	mBucket_Inc			: out	std_logic;
	
	LastRound			: in	std_logic;
	
	Mem_Addr			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr				: out	std_logic;
	Mem_Do				: out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	
	Param_r				: in	Natural range 0 to gcst_Round-1 := 0;
	
	Stp4_IdxReqNum		: out	Natural;
	Stp4_IdxReq			: out	std_logic;
	Stp4_IdxAckVal		: in	Natural;
	Stp4_IdxAck			: in	std_logic;
	
	Stp5_IdxReqNum		: out	Natural;
	Stp5_IdxReq			: out	std_logic;
	Stp5_IdxAckVal		: in	Natural;
	Stp5_IdxAck			: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_mBucket_Wrapper
generic(
	Device_Family	: string := Device_Family;
	mBucket_Width	: Natural := mBucket_Width;
	mBucket_Offset	: Natural := mBucket_Offset;
	mBucket_Num		: Natural := mBucket_Num;
	mBucket_MaxCap	: Natural := mBucket_MaxCap -- 3*2**9
);
port (
	ChAi_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_Get			: in	std_logic;
	ChAi_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	ChAi_D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1;
	ChAi_Inc			: in	std_logic;
	ChAi_Init			: in	std_logic;
	ChAi_Cnt_o			: out	Natural range 0 to mBucket_MaxCap;
	ChAi_Rdy			: out	std_logic;
	
	ChBi_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_Get			: in	std_logic;
	ChBi_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	ChBi_D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1;
	ChBi_Inc			: in	std_logic;
	ChBi_Init			: in	std_logic;
	ChBi_Cnt_o			: out	Natural range 0 to mBucket_MaxCap;
	ChBi_Rdy			: out	std_logic;
	
	Mem_D				: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr				: out	std_logic;
	
	M_Config			: in	std_logic; -- high priority
	M_IncSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	M_GetSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	M_MemChSel			: in	std_logic; -- '0': A->o; '1': B->o
	
	S_Config			: in	std_logic;
	S_IncSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	S_GetSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	S_MemChSel			: in	std_logic; -- '0': A->o; '1': B->o
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Lg_MultAdd
generic(
	Num			: Natural := Num_sThread
);
port (
	Di			: in	typ_1D_Nat(Num-1 downto 0);
	Do			: out	Natural;
	
	clk			: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	Num				: Positive := Num_sThread;
	Typ				: string := "and"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "true" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Equihash_GBP_UnCompress
generic(
	Device_Family		: string := Device_Family;
	AB_IdxArr_M			: Natural := to_integer(cst_AB_IdxArr_M);
	AB_IdxArr_Sect		: Natural := to_integer(cst_AB_IdxArr_Sect)
);
port (
	Num_Idx				: in	Natural; -- must be hold outter
	
	Mem_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_Di				: in	unsigned(gcst_WD_Idx-1 downto 0);
	Mem_RdAck			: in	std_logic;
	
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_Idx-1 downto 0);
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Equihash_GBP_IdxMng
generic(
	Num_Ch		: Natural := Num_sThread
);
port (
	ReqNum	: in	typ_1D_Nat(Num_Ch-1 downto 0);
	Req		: in	unsigned(Num_Ch-1 downto 0);
	
	AckVal	: out	Natural;
	Ack		: out	unsigned(Num_Ch-1 downto 0);
	
	TotNum	: out	Natural;
	Rst		: in	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_r					: Natural range 0 to gcst_Round-1;

signal sgn_sThread_Ed			: unsigned(Num_sThread-1 downto 0);

signal sgn_sBucket_Di			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_sBucket_Inc			: unsigned(Num_sThread-1 downto 0);
signal sgn_sThread_Sel			: Natural range 0 to Num_sThread-1;
signal sgn_sThread_St			: unsigned(Num_sThread-1 downto 0);
signal sgn_sThread_St_org		: std_logic;

signal sgn_mBucketRt_Config		: std_logic;
signal sgn_mBucketRt_IncSet		: std_logic; -- '0': A->A, B->B; '1': A->B, B->A
signal sgn_mBucketRt_GetSet		: std_logic; -- '0': A->A, B->B; '1': A->B, B->A
signal sgn_mBucketRt_MemChSel	: std_logic; -- '0': A->o; '1': B->o

signal sgn_mBucket_Init			: std_logic;
signal sgn_mBucket_Rdy_dst		: std_logic;
signal sgn_mBucket_Rdy			: unsigned(Num_sThread-1 downto 0);
signal sgn_mBucket_ChunkSel		: Natural range 0 to gcst_N_Chunk-1 := 0;
signal sgn_mBucket_AB_Buff		: unsigned(gcst_WA_Mem-1 downto 0);

signal sgn_mBucket_Get			: std_logic;
signal sgn_mBucket_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
signal sgn_mBucket_Cnt			: typ_1D_Nat(Num_sThread-1 downto 0);

signal sgn_mBucket_Di			: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mBucket_Inc			: unsigned(Num_sThread-1 downto 0);

signal sgn_Bucket_Rdy			: unsigned(Num_sThread-1 downto 0); -- for outter

signal sgn_LastRound				: std_logic;
signal sgn_mBucket_CntSum		: Natural;

signal sgn_sBucket_ChunkSel		: Natural range 0 to gcst_N_Chunk-1;

signal sgn_UnCompress_St		: std_logic;

signal sgn_Stp4_IdxReqNum		: typ_1D_Nat(Num_sThread-1 downto 0);
signal sgn_Stp4_IdxReq			: unsigned(Num_sThread-1 downto 0);
signal sgn_Stp4_IdxAck			: unsigned(Num_sThread-1 downto 0);
signal sgn_Stp4_IdxAckVal		: Natural;

signal sgn_Stp5_IdxReqNum		: typ_1D_Nat(Num_sThread-1 downto 0);
signal sgn_Stp5_IdxReq			: unsigned(Num_sThread-1 downto 0);
signal sgn_Stp5_IdxAck			: unsigned(Num_sThread-1 downto 0);
signal sgn_Stp5_IdxAckVal		: Natural;

signal sgn_UnC_NumIdx			: Natural;
signal sgn_IdxMngRst			: std_logic;
--============================ function declare ============================--

begin

inst01: Equihash_GBP_CllsMThread
port map(
	mBucketRt_Config	=> sgn_mBucketRt_Config,--: out	std_logic;
	mBucketRt_IncSet	=> sgn_mBucketRt_IncSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_GetSet	=> sgn_mBucketRt_GetSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_MemChSel	=> sgn_mBucketRt_MemChSel,--: out	std_logic; -- '0': A->o; '1': B->o
	
	mBucket_Init		=> sgn_mBucket_Init,--: out	std_logic;
	mBucket_Rdy			=> sgn_mBucket_Rdy_dst,--: in	std_logic;
	mBucket_ChunkSel	=> sgn_mBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	mBucket_AB_Buff		=> sgn_mBucket_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucket_Get			=> sgn_mBucket_Get,--: out	std_logic;
	mBucket_GetIdx		=> sgn_mBucket_GetIdx,--: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	mBucket_Cnt			=> sgn_mBucket_CntSum,--: in	Natural range 0 to mBucket_MaxCap;
	
	IdxMngRst			=> sgn_IdxMngRst,--: out	std_logic;
	LastRound			=> sgn_LastRound,--: out std_logic;
	
	sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1;

	Mem_Addr			=> Mem_p1_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				=> Mem_p1_Rd,--(io): out	std_logic;
	Mem_RdAck			=> Mem_p1_RdAck,--(io): in	std_logic;
	
	Param_r				=> sgn_r,--: out	Natural range 0 to gcst_Round-1 := 0;
	
	sThread_Sel			=> sgn_sThread_Sel,--: out Natural range 0 to Num_sThread-1;
	sThread_Ed			=> sgn_sThread_Ed,--: in	unsigned(Num_sThread-1 downto 0);
	sThread_St			=> sgn_sThread_St_org,--: out	std_logic;
	
	St					=> St,--(io): in	std_logic;
	Ed					=> sgn_UnCompress_St,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

i0100: for i in 0 to Num_sThread-1 generate
	inst02: Equihash_GBP_CllsSThread
	port map(
		sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
		
		sBucket_Di			=> sgn_sBucket_Di,--: in	unsigned(gcst_WD_Mem-1 downto 0);
		sBucket_Inc			=> sgn_sBucket_Inc(i),--: in	std_logic;
		
		mBucket_Di			=> sgn_mBucket_Di(i),--: out unsigned(gcst_WD_Mem-1 downto 0);
		mBucket_Inc			=> sgn_mBucket_Inc(i),--: out	std_logic;
		LastRound			=> sgn_LastRound,--: in	std_logic;
		
		Mem_Addr			=> Mem_p2_A(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_Wr				=> Mem_p2_Wr(i),--(io): out	std_logic;
		Mem_Do				=> Mem_p2_Do(i),--(io): out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
		
		Param_r				=> sgn_r,--: in	Natural range 0 to gcst_Round-1 := 0;
		
		Stp4_IdxReqNum		=> sgn_Stp4_IdxReqNum(i),--: out	Natural;
		Stp4_IdxReq			=> sgn_Stp4_IdxReq(i),--: out	std_logic;
		Stp4_IdxAckVal		=> sgn_Stp4_IdxAckVal,--: in	Natural;
		Stp4_IdxAck			=> sgn_Stp4_IdxAck(i),--: in	std_logic;
		
		Stp5_IdxReqNum		=> sgn_Stp5_IdxReqNum(i),--: out	Natural;
		Stp5_IdxReq			=> sgn_Stp5_IdxReq(i),--: out	std_logic;
		Stp5_IdxAckVal		=> sgn_Stp5_IdxAckVal,--: in	Natural;
		Stp5_IdxAck			=> sgn_Stp5_IdxAck(i),--: in	std_logic;
	
		St					=> sgn_sThread_St(i),--: in	std_logic;
		Ed					=> sgn_sThread_Ed(i),--: out	std_logic;
		
		clk					=> clk,--: in	std_logic;
		aclr				=> aclr--: in	std_logic
	);
	
	inst03: Equihash_mBucket_Wrapper
	port map(
		ChAi_Init			=> Bucket_Init,--(io): in	std_logic;
		ChAi_Rdy			=> sgn_Bucket_Rdy(i),--(io): out	std_logic;
		ChAi_AB_Buff		=> Bucket_AB_Buff,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
		ChAi_ChunkSel		=> Bucket_ChunkSel,--fixed: in	Natural range 0 to gcst_N_Chunk-1;
		ChAi_D_i			=> Bucket_Di,--(io): in	unsigned(gcst_WD_Mem-1 downto 0);
		ChAi_Inc			=> Bucket_Inc,--(io): in	std_logic;
		ChAi_Get			=> '0',--(io): in	std_logic;
		ChAi_GetIdx			=> to_unsigned(0,gcst_W_Chunk),--(io): in	unsigned(gcst_W_Chunk-1 downto 0);
		ChAi_Cnt_o			=> open,--(io): out	Natural range 0 to mBucket_MaxCap;
		
		ChBi_Init			=> sgn_mBucket_Init,--: in	std_logic;
		ChBi_Rdy			=> sgn_mBucket_Rdy(i),--: out	std_logic;
		ChBi_AB_Buff		=> sgn_mBucket_AB_Buff,--: in	unsigned(gcst_WA_Mem-1 downto 0);
		ChBi_ChunkSel		=> sgn_mBucket_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
		ChBi_D_i			=> sgn_mBucket_Di(i),--: in	unsigned(gcst_WD_Mem-1 downto 0);
		ChBi_Inc			=> sgn_mBucket_Inc(i),--: in	std_logic;
		ChBi_Get			=> sgn_mBucket_Get,--: in	std_logic;
		ChBi_GetIdx			=> sgn_mBucket_GetIdx,--: in	unsigned(gcst_W_Chunk-1 downto 0);
		ChBi_Cnt_o			=> sgn_mBucket_Cnt(i),--: out	Natural range 0 to mBucket_MaxCap;
		
		Mem_D				=> Mem_p3_Do(i),--(io): out	unsigned(gcst_WD_Mem-1 downto 0);
		Mem_A				=> Mem_p3_A(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_Wr				=> Mem_p3_Wr(i),--(io): out	std_logic;
		
		M_Config			=> BucketRt_Config,--(io): in	std_logic; -- high priority
		M_IncSet			=> BucketRt_IncSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		M_GetSet			=> BucketRT_GetSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		M_MemChSel			=> BucketRt_MemChSel,--(io): in	std_logic; -- '0': A->o; '1': B->o
		
		S_Config			=> sgn_mBucketRt_Config,--: in	std_logic;
		S_IncSet			=> sgn_mBucketRt_IncSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		S_GetSet			=> sgn_mBucketRt_GetSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		S_MemChSel			=> sgn_mBucketRt_MemChSel,--: in	std_logic; -- '0': A->o; '1': B->o
		
		clk					=> clk,--: in	std_logic;
		aclr				=> aclr--: in	std_logic
	);
end generate i0100;

-- mem read input
process(clk)
begin
	if(rising_edge(clk))then
		sgn_sBucket_Di <= Mem_p1_Di; -- delay 1 clk
	end if;
end process;

-- sBucket inc dispatch
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_sBucket_Inc <= (others => '0');
	elsif(rising_edge(clk))then
		for i in 0 to Num_sThread-1 loop
			if(i=sgn_sThread_Sel)then
				sgn_sBucket_Inc(i) <= Mem_p1_RdAck;
			else
				sgn_sBucket_Inc(i) <= '0';
			end if;
		end loop;
	end if;
end process;

-- sThread st dispatch
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_sThread_St <= (others => '0');
	elsif(rising_edge(clk))then
		for i in 0 to Num_sThread-1 loop
			if(i=sgn_sThread_Sel)then
				sgn_sThread_St(i) <= sgn_sThread_St_org;
			else
				sgn_sThread_St(i) <= '0';
			end if;
		end loop;
	end if;
end process;

-- mBucket cnt sum
inst04: Lg_MultAdd
port map(
	Di			=> sgn_mBucket_Cnt,--: in	typ_1D_Nat(Num-1 downto 0);
	Do			=> sgn_mBucket_CntSum,--: out	Natural;
	
	clk			=> clk--: in	std_logic
);

-- mBucket ready all and
inst05: Lg_BoolOpt
port map(
	Di			=> sgn_Bucket_Rdy,--: in	unsigned(Num-1 downto 0);
	Do			=> Bucket_Rdy,--(io): out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

inst06: Lg_BoolOpt
port map(
	Di			=> sgn_mBucket_Rdy,--: in	unsigned(Num-1 downto 0);
	Do			=> sgn_mBucket_Rdy_dst,--(io): out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

inst07: Equihash_GBP_UnCompress
port map(
	Num_Idx			=> sgn_UnC_NumIdx,--: in	Natural; -- must be hold outter
	
	Mem_A			=> Mem_p4_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			=> Mem_p4_Rd,--(io): out	std_logic;
	Mem_Di			=> Mem_p4_Di(gcst_WD_Mem_Apdix-1 downto 0),--(io): in	unsigned(gcst_WD_Idx-1 downto 0);
	Mem_RdAck		=> Mem_p4_RdAck,--(io): in	std_logic;
	
	ResValid		=> ResValid,--(io): out	std_logic;
	Res				=> Res,--(io): out	unsigned(gcst_WD_Idx-1 downto 0);
	
	St				=> sgn_UnCompress_St,--: in	std_logic;
	Ed				=> Ed,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

inst08: Equihash_GBP_IdxMng
port map(
	ReqNum	=> sgn_Stp4_IdxReqNum,--: in	Natural;
	Req		=> sgn_Stp4_IdxReq,--: in	unsigned(Num_Ch-1 downto 0);
	
	AckVal	=> sgn_Stp4_IdxAckVal,--: out	Natural;
	Ack		=> sgn_Stp4_IdxAck,--: out	unsigned(Num_Ch-1 downto 0);
	
	TotNum	=> open,--: out	Natural;
	Rst		=> sgn_IdxMngRst,--: in	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

inst09: Equihash_GBP_IdxMng
port map(
	ReqNum	=> sgn_Stp5_IdxReqNum,--: in	Natural;
	Req		=> sgn_Stp5_IdxReq,--: in	unsigned(Num_Ch-1 downto 0);
	
	AckVal	=> sgn_Stp5_IdxAckVal,--: out	Natural;
	Ack		=> sgn_Stp5_IdxAck,--: out	unsigned(Num_Ch-1 downto 0);
	
	TotNum	=> sgn_UnC_NumIdx,--: out	Natural;
	Rst		=> sgn_IdxMngRst,--: in	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

end rtl;
