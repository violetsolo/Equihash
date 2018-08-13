----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    15/06/2018 
-- Design Name: 
-- Module Name:    Equihash_mBucket_Wrapper - Behavioral
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

entity Equihash_mBucket_Wrapper is
generic(
	Device_Family	: string := "Cyclone V";
	mBucket_Width	: Natural := 12;
	mBucket_Offset	: Natural := 0;
	mBucket_Num		: Natural := 2**12;
	mBucket_MaxCap	: Natural := 2**11 -- 3*2**9
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
	M_IncSet			: in	std_logic; -- '0': A->Am, B->Bm; '1': A->Bm, B->Am
	M_GetSet			: in	std_logic; -- '0': Am->A, Bm->B; '1': Am->B, Bm->A
	M_MemChSel			: in	std_logic; -- '0': Am->o; '1': Bm->o
	
	S_Config			: in	std_logic;
	S_IncSet			: in	std_logic; -- '0': A->Am, B->Bm; '1': A->Bm, B->Am
	S_GetSet			: in	std_logic; -- '0': Am->A, Bm->B; '1': Am->B, Bm->A
	S_MemChSel			: in	std_logic; -- '0': Am->o; '1': Bm->o
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_mBucket_Wrapper;

architecture rtl of Equihash_mBucket_Wrapper is
--============================ constant declare ============================--
constant cst_AB_mBucket_Sect	: unsigned(gcst_WA_Mem-1 downto 0) := to_unsigned(mBucket_MaxCap, gcst_WA_Mem);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_BucketDisp
generic(
	Device_Family	: string := Device_Family;
	TypCounter		: string := "Ram"; --"Ram" or "Arr"
	Width_Addr		: Natural := gcst_WA_Mem;
	Bucket_Width	: Natural := mBucket_Width;
	Bucket_Offset	: Natural := mBucket_Offset;
	Bucket_Num		: Natural := mBucket_Num;
	Bucket_MaxCap	: Natural := mBucket_MaxCap -- 3*2**9
);
port (
	AB_Bucket	: in	unsigned(Width_Addr-1 downto 0);
	AB_Buff		: in	unsigned(Width_Addr-1 downto 0);

	D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	Inc			: in	std_logic;
			
	Mem_D		: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A		: out	unsigned(Width_Addr-1 downto 0);
	Mem_Wr		: out	std_logic;
	
	Get			: in	std_logic;
	GetIdx		: in	unsigned(gcst_W_Chunk-1 downto 0); -- heed: value locate at Bucket_Offset+Fnc_Int2Wd(Bucket_Num-1)-1 downto Bucket_Offset
	Cnt_o		: out	Natural range 0 to Bucket_MaxCap;
	
	Init		: in	std_logic;
	Rdy			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;

component Equihash_BucketRt2X2
generic(
	Max_Counter		: Natural := mBucket_MaxCap -- 3*2**9
);
port (
	ChAi_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_Get			: in	std_logic;
	ChAi_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	ChAi_D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1;
	ChAi_Inc			: in	std_logic;
	ChAi_Init			: in	std_logic;
	ChAi_Cnt_o			: out	Natural range 0 to Max_Counter;
	ChAi_Rdy			: out	std_logic;
	
	ChBi_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_Get			: in	std_logic;
	ChBi_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	ChBi_D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1;
	ChBi_Inc			: in	std_logic;
	ChBi_Init			: in	std_logic;
	ChBi_Cnt_o			: out	Natural range 0 to Max_Counter;
	ChBi_Rdy			: out	std_logic;
	
	ChAO_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0);
	ChAO_Get			: out	std_logic;
	ChAO_GetIdx			: out	unsigned(gcst_W_Chunk-1 downto 0);
	ChAO_D_i			: out	unsigned(gcst_WD_Mem-1 downto 0);
	ChAO_ChunkSel		: out	Natural range 0 to gcst_N_Chunk-1;
	ChAO_Inc			: out	std_logic;
	ChAO_Init			: out	std_logic;
	ChAO_Cnt_o			: in	Natural range 0 to Max_Counter;
	ChAO_Rdy			: in	std_logic;
	
	ChBO_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0);
	ChBO_Get			: out	std_logic;
	ChBO_GetIdx			: out	unsigned(gcst_W_Chunk-1 downto 0);
	ChBO_D_i			: out	unsigned(gcst_WD_Mem-1 downto 0);
	ChBO_ChunkSel		: out	Natural range 0 to gcst_N_Chunk-1;
	ChBO_Inc			: out	std_logic;
	ChBO_Init			: out	std_logic;
	ChBO_Cnt_o			: in	Natural range 0 to Max_Counter;
	ChBO_Rdy			: in	std_logic;
	
	M_Config			: in	std_logic; -- high priority
	M_IncSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	M_GetSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	S_Config			: in	std_logic;
	S_IncSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	S_GetSet			: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_BucketMix
port (
	ChAi_A				: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_D				: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_Wr				: in	std_logic;
	
	ChBi_A				: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_D				: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_Wr				: in	std_logic;
	
	Cho_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Cho_D				: out	unsigned(gcst_WD_Mem-1 downto 0);
	Cho_Wr				: out	std_logic;
	
	M_Config			: in	std_logic; -- high priority
	M_ChSel				: in	std_logic; -- '0': A->o; '1': B->o
	
	S_Config			: in	std_logic;
	S_ChSel				: in	std_logic; -- '0': A->o; '1': B->o
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_ChAo_AB_Buff		: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_ChAo_Get			: std_logic;
signal sgn_ChAo_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0);
signal sgn_ChAo_D_i			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_ChAo_ChunkSel	: Natural range 0 to gcst_N_Chunk-1;
signal sgn_ChAo_Inc			: std_logic;
signal sgn_ChAo_Init		: std_logic;
signal sgn_ChAo_Cnt_o		: Natural range 0 to mBucket_MaxCap;
signal sgn_ChAo_Rdy			: std_logic;
	
signal sgn_ChBo_AB_Buff		: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_ChBo_Get			: std_logic;
signal sgn_ChBo_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0);
signal sgn_ChBo_D_i			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_ChBo_ChunkSel	: Natural range 0 to gcst_N_Chunk-1;
signal sgn_ChBo_Inc			: std_logic;
signal sgn_ChBo_Init		: std_logic;
signal sgn_ChBo_Cnt_o		: Natural range 0 to mBucket_MaxCap;
signal sgn_ChBo_Rdy			: std_logic;

signal sgn_ChAi_A			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_ChAi_D			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_ChAi_Wr			: std_logic;
	
signal sgn_ChBi_A			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_ChBi_D			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_ChBi_Wr			: std_logic;
--============================ function declare ============================--

begin

inst01: Equihash_BucketDisp -- mBucket A
port map(
	AB_Bucket	=> cst_AB_mBucket_Sect,--: in	unsigned(Width_Addr-1 downto 0);
	AB_Buff		=> sgn_ChAo_AB_Buff,--: in	unsigned(Width_Addr-1 downto 0);

	D_i			=> sgn_ChAo_D_i,--: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChunkSel	=> sgn_ChAo_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
	Inc			=> sgn_ChAo_Inc,--: in	std_logic;
			
	Mem_D		=> sgn_ChAi_D,--: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A		=> sgn_ChAi_A,--: out	unsigned(Width_Addr-1 downto 0);
	Mem_Wr		=> sgn_ChAi_Wr,--: out	std_logic;
	
	Get			=> sgn_ChAo_Get,--: in	std_logic;
	GetIdx		=> sgn_ChAo_GetIdx,--: in	unsigned(gcst_W_Chunk-1 downto 0); -- heed: value locate at Bucket_Offset+Fnc_Int2Wd(Bucket_Num-1)-1 downto Bucket_Offset
	Cnt_o		=> sgn_ChAo_Cnt_o,--: out	Natural range 0 to Bucket_MaxCap;
	
	Init		=> sgn_ChAo_Init,--: in	std_logic;
	Rdy			=> sgn_ChAo_Rdy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic := '0'
);

inst02: Equihash_BucketDisp -- mBucket B
port map(
	AB_Bucket	=> cst_AB_mBucket_Sect,--: in	unsigned(Width_Addr-1 downto 0);
	AB_Buff		=> sgn_ChBo_AB_Buff,--: in	unsigned(Width_Addr-1 downto 0);

	D_i			=> sgn_ChBo_D_i,--: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChunkSel	=> sgn_ChBo_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
	Inc			=> sgn_ChBo_Inc,--: in	std_logic;
			
	Mem_D		=> sgn_ChBi_D,--: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A		=> sgn_ChBi_A,--: out	unsigned(Width_Addr-1 downto 0);
	Mem_Wr		=> sgn_ChBi_Wr,--: out	std_logic;
	
	Get			=> sgn_ChBo_Get,--: in	std_logic;
	GetIdx		=> sgn_ChBo_GetIdx,--: in	unsigned(gcst_W_Chunk-1 downto 0); -- heed: value locate at Bucket_Offset+Fnc_Int2Wd(Bucket_Num-1)-1 downto Bucket_Offset
	Cnt_o		=> sgn_ChBo_Cnt_o,--: out	Natural range 0 to Bucket_MaxCap;
	
	Init		=> sgn_ChBo_Init,--: in	std_logic;
	Rdy			=> sgn_ChBo_Rdy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic := '0'
);

inst03: Equihash_BucketRt2X2
port map(
	ChAi_AB_Buff		=> ChAi_AB_Buff,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_Get			=> ChAi_Get,--(io): in	std_logic;
	ChAi_GetIdx			=> ChAi_GetIdx,--(io): in	unsigned(gcst_W_Chunk-1 downto 0);
	ChAi_D_i			=> ChAi_D_i,--(io): in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_ChunkSel		=> ChAi_ChunkSel,--(io): in	Natural range 0 to gcst_N_Chunk-1;
	ChAi_Inc			=> ChAi_Inc,--(io): in	std_logic;
	ChAi_Init			=> ChAi_Init,--(io): in	std_logic;
	ChAi_Cnt_o			=> ChAi_Cnt_o,--(io): out	Natural range 0 to Max_Counter;
	ChAi_Rdy			=> ChAi_Rdy,--(io): out	std_logic;
	
	ChBi_AB_Buff		=> ChBi_AB_Buff,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_Get			=> ChBi_Get,--(io): in	std_logic;
	ChBi_GetIdx			=> ChBi_GetIdx,--(io): in	unsigned(gcst_W_Chunk-1 downto 0);
	ChBi_D_i			=> ChBi_D_i,--(io): in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_ChunkSel		=> ChBi_ChunkSel,--(io): in	Natural range 0 to gcst_N_Chunk-1;
	ChBi_Inc			=> ChBi_Inc,--(io): in	std_logic;
	ChBi_Init			=> ChBi_Init,--(io): in	std_logic;
	ChBi_Cnt_o			=> ChBi_Cnt_o,--(io): out	Natural range 0 to Max_Counter;
	ChBi_Rdy			=> ChBi_Rdy,--(io): out	std_logic;
	
	ChAO_AB_Buff		=> sgn_ChAo_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	ChAO_Get			=> sgn_ChAo_Get,--: out	std_logic;
	ChAO_GetIdx			=> sgn_ChAo_GetIdx,--: out	unsigned(gcst_W_Chunk-1 downto 0);
	ChAO_D_i			=> sgn_ChAo_D_i,--: out	unsigned(gcst_WD_Mem-1 downto 0);
	ChAO_ChunkSel		=> sgn_ChAo_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1;
	ChAO_Inc			=> sgn_ChAo_Inc,--: out	std_logic;
	ChAO_Init			=> sgn_ChAo_Init,--: out	std_logic;
	ChAO_Cnt_o			=> sgn_ChAo_Cnt_o,--: in	Natural range 0 to Max_Counter;
	ChAO_Rdy			=> sgn_ChAo_Rdy,--: in	std_logic;
	
	ChBO_AB_Buff		=> sgn_ChBo_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	ChBO_Get			=> sgn_ChBo_Get,--: out	std_logic;
	ChBO_GetIdx			=> sgn_ChBo_GetIdx,--: out	unsigned(gcst_W_Chunk-1 downto 0);
	ChBO_D_i			=> sgn_ChBo_D_i,--: out	unsigned(gcst_WD_Mem-1 downto 0);
	ChBO_ChunkSel		=> sgn_ChBo_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1;
	ChBO_Inc			=> sgn_ChBo_Inc,--: out	std_logic;
	ChBO_Init			=> sgn_ChBo_Init,--: out	std_logic;
	ChBO_Cnt_o			=> sgn_ChBo_Cnt_o,--: in	Natural range 0 to Max_Counter;
	ChBO_Rdy			=> sgn_ChBo_Rdy,--: in	std_logic;
	
	M_Config			=> M_Config,--(io): in	std_logic; -- high priority
	M_IncSet			=> M_IncSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	M_GetSet			=> M_GetSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	S_Config			=> S_Config,--(io): in	std_logic;
	S_IncSet			=> S_IncSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	S_GetSet			=> S_GetSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

inst04: Equihash_BucketMix
port map(
	ChAi_A				=> sgn_ChAi_A,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_D				=> sgn_ChAi_D,--: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_Wr				=> sgn_ChAi_Wr,--: in	std_logic;
	
	ChBi_A				=> sgn_ChBi_A,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_D				=> sgn_ChBi_D,--: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_Wr				=> sgn_ChBi_Wr,--: in	std_logic;
	
	Cho_A				=> Mem_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Cho_D				=> Mem_D,--(io): out	unsigned(gcst_WD_Mem-1 downto 0);
	Cho_Wr				=> Mem_Wr,--(io): out	std_logic;
	
	M_Config			=> M_Config,--(io): in	std_logic; -- high priority
	M_ChSel				=> M_MemChSel,--(io): in	std_logic; -- '0': A->o; '1': B->o
	
	S_Config			=> S_Config,--(io): in	std_logic;
	S_ChSel				=> S_MemChSel,--(io): in	std_logic; -- '0': A->o; '1': B->o
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);


end rtl;

