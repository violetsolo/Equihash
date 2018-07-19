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
	Num_sThread			: Positive := 1
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
	Bucket_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Bucket_Inc			: in	unsigned(Num_sThread-1 downto 0);
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
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	-- GBP process strat
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Equihash_GBP_Wrapper;

architecture rtl of Equihash_GBP_Wrapper is
--============================ constant declare ============================--
constant cst_mBucket_CntSumDL	: Natural := Fnc_Int2Wd(Num_sThread-1);

--======================== Altera component declare ========================--
component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL := gcst_mBucket_Num;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL := gcst_WA_Mem; -- 32
	lpm_widthu					: NATURAL := Fnc_Int2Wd(gcst_mBucket_Num-1); -- log2(128)
	overflow_checking			: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab						: STRING := "ON"
);
port (
	data				: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				: IN STD_LOGIC ;

	q					: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				: IN STD_LOGIC ;
	
	empty				: OUT STD_LOGIC ;

	clock				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;
--===================== user-defined component declare =====================--
component Equihash_GBP_CllsMThread
generic(
	Num_sThread			: Natural := Num_sThread;
	mBucket_CntSumDL	: Natural := cst_mBucket_CntSumDL -- log2(Num_sThread)
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
	
	LastRound			: out	std_logic;
	AB_RamIdx			: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1;

	Mem_Addr			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_RdAck			: in	std_logic;
	
	Param_r				: out	Natural range 0 to gcst_Round := 0;
	
	sThread_Sel			: out Natural range 0 to Num_sThread-1;
	sThread_Ed			: in	unsigned(Num_sThread-1 downto 0);
	sThread_St			: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_CllsSThread
generic(
	Device_Family		: string := Device_Family
);
port (
	Param_r				: in	Natural range 0 to gcst_Round := 0;
	AB_RamIdx			: in	unsigned(gcst_WA_Mem-1 downto 0);
	LastRound			: in	std_logic;
	
	sBucket_ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	sBucket_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	sBucket_Inc			: in	std_logic;
	
	mBucket_Di			: out unsigned(gcst_WD_Mem-1 downto 0);
	mBucket_Inc			: out	std_logic;
	
	Mem_Addr			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr				: out	std_logic;
	Mem_Do				: out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	
	InfoLst_AB			: out	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			: out	Natural range 0 to gcst_mBucket_MaxCap;
	InfoLst_Wr			: out	std_logic;
	
	sThEd_Req			: out	std_logic;
	sThEd_Ack			: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_mBucket_Wrapper
generic(
	Device_Family	: string := Device_Family;
	mBucket_Width	: Natural := gcst_mBucket_Width;
	mBucket_Offset	: Natural := gcst_mBucket_Offset;
	mBucket_Num		: Natural := gcst_mBucket_Num;
	mBucket_MaxCap	: Natural := gcst_mBucket_MaxCap -- 3*2**9
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
	Device_Family		: string := Device_Family
);
port (
	Mem_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_Di				: in	unsigned(gcst_WD_idxCache-1 downto 0);
	Mem_RdAck			: in	std_logic;
	
	InfoLst_AB			: in	unsigned(gcst_WD_idxCache-1 downto 0);
	InfoLst_Num			: in	Natural;
	InfoLst_Rd			: out	std_logic;
	InfoLst_Emp			: in	std_logic;
	
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	
	Bsy					: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Robin_TypI
generic(
	Robin_Num		: Natural := Num_sThread
);
port (
	Req				: in	unsigned(Robin_Num-1 downto 0);
	Ack				: out	unsigned(Robin_Num-1 downto 0);
	
	Sel				: out	Natural range 0 to Robin_Num-1;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_r					: Natural range 0 to gcst_Round;

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

signal sgn_AB_RamIdx			: unsigned(gcst_WA_Mem-1 downto 0);

signal sgn_sThEd_Req			: unsigned(Num_sThread-1 downto 0);
signal sgn_sThEd_Ack			: unsigned(Num_sThread-1 downto 0);
signal sgn_InfoLst_Sel			: Natural range 0 to Num_sThread-1;
signal sgn_InfoLst_Sel_DL1		: Natural range 0 to Num_sThread-1;
signal sgn_InfoLst_Sel_DL2		: Natural range 0 to Num_sThread-1;

type typ_InfoLstAB is array (natural range <>) of unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_InfoLstAB			: typ_InfoLstAB(Num_sThread-1 downto 0);
signal sgn_InfoLstNum			: typ_1D_Nat(Num_sThread-1 downto 0);
signal sgn_InfoLstWr			: unsigned(Num_sThread-1 downto 0);

signal sgn_InfoLstAB_Mo			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_InfoLstNum_Mo		: Natural;
signal sgn_InfoLstWr_Mo			: std_logic;

signal sgn_FIFO_InfoLstAB_Do		: std_logic_vector(gcst_WA_Mem-1 downto 0);
signal sgn_FIFO_InfoLstNum_Do		: std_logic_vector(gcst_WA_Mem-1 downto 0);
signal sgn_FIFO_InfoLstAB_Rd		: std_logic;
signal sgn_FIFO_InfoLstNum_Rd		: std_logic;
signal sgn_FIFO_InfoLst_Emp			: std_logic;

signal sgn_InfoLst_AB				: unsigned(gcst_WD_idxCache-1 downto 0);
signal sgn_InfoLst_Num				: Natural;
signal sgn_InfoLst_Rd				: std_logic;
signal sgn_InfoLst_Emp				: std_logic;

signal sgn_UnCBsy					: std_logic;
signal sgn_GBPEd					: std_logic;

type typ_state is (S_Idle, S_P1, S_P2);
signal state				: typ_state;
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
	
	LastRound			=> sgn_LastRound,--: out std_logic;
	AB_RamIdx			=> sgn_AB_RamIdx,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1;

	Mem_Addr			=> Mem_p1_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				=> Mem_p1_Rd,--(io): out	std_logic;
	Mem_RdAck			=> Mem_p1_RdAck,--(io): in	std_logic;
	
	Param_r				=> sgn_r,--: out	Natural range 0 to gcst_Round-1 := 0;
	
	sThread_Sel			=> sgn_sThread_Sel,--: out Natural range 0 to Num_sThread-1;
	sThread_Ed			=> sgn_sThread_Ed,--: in	unsigned(Num_sThread-1 downto 0);
	sThread_St			=> sgn_sThread_St_org,--: out	std_logic;
	
	St					=> St,--(io): in	std_logic;
	Ed					=> sgn_GBPEd,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

i0100: for i in 0 to Num_sThread-1 generate
	inst02: Equihash_GBP_CllsSThread
	port map(
		Param_r				=> sgn_r,--: in	Natural range 0 to gcst_Round-1 := 0;
		AB_RamIdx			=> sgn_AB_RamIdx,--: in	unsigned(gcst_WA_Mem-1 downto 0);
		LastRound			=> sgn_LastRound,--: in	std_logic;
		
		sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
		sBucket_Di			=> sgn_sBucket_Di,--: in	unsigned(gcst_WD_Mem-1 downto 0);
		sBucket_Inc			=> sgn_sBucket_Inc(i),--: in	std_logic;
		
		mBucket_Di			=> sgn_mBucket_Di(i),--: out unsigned(gcst_WD_Mem-1 downto 0);
		mBucket_Inc			=> sgn_mBucket_Inc(i),--: out	std_logic;
		
		Mem_Addr			=> Mem_p2_A(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_Wr				=> Mem_p2_Wr(i),--(io): out	std_logic;
		Mem_Do				=> Mem_p2_Do(i),--(io): out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
		
		InfoLst_AB			=> sgn_InfoLstAB(i),--: out	unsigned(gcst_WA_Mem-1 downto 0);
		InfoLst_Num			=> sgn_InfoLstNum(i),--: out	Natural range 0 to gcst_mBucket_MaxCap;
		InfoLst_Wr			=> sgn_InfoLstWr(i),--: out	std_logic;
		
		sThEd_Req			=> sgn_sThEd_Req(i),--: out	std_logic;
		sThEd_Ack			=> sgn_sThEd_Ack(i),--: in	std_logic;
		
		St					=> sgn_sThread_St(i),--: in	std_logic;
		Ed					=> sgn_sThread_Ed(i),--: out	std_logic;
		Bsy					=> open,--: out	std_logic;
		
		clk					=> clk,--: in	std_logic;
		aclr				=> aclr--: in	std_logic
	);
	
	inst03: Equihash_mBucket_Wrapper
	port map(
		ChAi_Init			=> Bucket_Init,--(io): in	std_logic;
		ChAi_Rdy			=> sgn_Bucket_Rdy(i),--(io): out	std_logic;
		ChAi_AB_Buff		=> Bucket_AB_Buff,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
		ChAi_ChunkSel		=> Bucket_ChunkSel,--fixed: in	Natural range 0 to gcst_N_Chunk-1;
		ChAi_D_i			=> Bucket_Di(i),--(io): in	unsigned(gcst_WD_Mem-1 downto 0);
		ChAi_Inc			=> Bucket_Inc(i),--(io): in	std_logic;
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
	Mem_A			=> Mem_p4_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			=> Mem_p4_Rd,--(io): out	std_logic;
	Mem_Di			=> Mem_p4_Di(gcst_WD_Mem_Apdix-1 downto 0),--(io): in	unsigned(gcst_WD_Idx-1 downto 0);
	Mem_RdAck		=> Mem_p4_RdAck,--(io): in	std_logic;
	
	InfoLst_AB		=> sgn_InfoLst_AB,--: in	unsigned(gcst_WD_idxCache-1 downto 0);
	InfoLst_Num		=> sgn_InfoLst_Num,--: in	Natural;
	InfoLst_Rd		=> sgn_InfoLst_Rd,--: out	std_logic;
	InfoLst_Emp		=> sgn_InfoLst_Emp,--: in	std_logic;
	
	ResValid		=> ResValid,--(io): out	std_logic;
	Res				=> Res,--(io): out	unsigned(gcst_WD_Idx-1 downto 0);
	
	Bsy				=> sgn_UnCBsy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- last round info save
inst08: Lg_Robin_TypI
port map(
	Req				=> sgn_sThEd_Req,--: in	unsigned(Robin_Num-1 downto 0);
	Ack				=> sgn_sThEd_Ack,--: out	unsigned(Robin_Num-1 downto 0);
	
	Sel				=> sgn_InfoLst_Sel,--: out	Natural range 0 to Robin_Num-1;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- sel delay 2clk
process(clk)
begin
	if(rising_edge(clk))then
		sgn_InfoLst_Sel_DL1 <= sgn_InfoLst_Sel;
		sgn_InfoLst_Sel_DL2 <= sgn_InfoLst_Sel_DL1;
	end if;
end process;

-- date Mux
process(clk)
begin
	if(rising_edge(clk))then
		sgn_InfoLstAB_Mo <= sgn_InfoLstAB(sgn_InfoLst_Sel_DL2);
		sgn_InfoLstNum_Mo <= sgn_InfoLstNum(sgn_InfoLst_Sel_DL2);
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_InfoLstWr_Mo <= '0';
	elsif(rising_edge(clk))then
		sgn_InfoLstWr_Mo <= sgn_InfoLstWr(sgn_InfoLst_Sel_DL2);
	end if;
end process;

-- fifo
inst09: scfifo -- AB
port map(
	data				=> std_logic_vector(sgn_InfoLstAB_Mo),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_InfoLstWr_Mo,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_InfoLstAB_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_InfoLstAB_Rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_FIFO_InfoLst_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst10: scfifo -- Num
port map(
	data				=> std_logic_vector(to_unsigned(sgn_InfoLstNum_Mo,gcst_WA_Mem)),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_InfoLstWr_Mo,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_InfoLstNum_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_InfoLstNum_Rd,--: IN STD_LOGIC ;
	
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_FIFO_InfoLstAB_Rd <= sgn_InfoLst_Rd;
sgn_FIFO_InfoLstNum_Rd <= sgn_InfoLst_Rd;
sgn_InfoLst_Emp <= sgn_FIFO_InfoLst_Emp;
sgn_InfoLst_AB <= unsigned(sgn_FIFO_InfoLstAB_Do);
sgn_InfoLst_Num <= to_integer(unsigned(sgn_FIFO_InfoLstNum_Do));

-- process end and bsy
process(clk,aclr)
begin
	if(aclr='1')then
		Ed <= '0';
		Bsy <= '0';
		state <= S_Idle;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					Bsy <= '1';
					state <= S_P1;
				else
					Bsy <= '0';
				end if;
			
			when S_P1 =>
				if(sgn_GBPEd='1')then
					state <= S_P2;
				end if;
			
			when S_P2 =>
				if(sgn_FIFO_InfoLst_Emp='1' and sgn_UnCBsy='0')then
					state <= S_Idle;
					Ed <= '1';
				end if;
			
			when others => state <= S_Idle;
		end case;
	end if;
end process;

end rtl;
