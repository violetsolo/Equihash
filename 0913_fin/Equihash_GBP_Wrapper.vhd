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
use work.Lg_BMix_MidWare_pkg.all;

entity Equihash_GBP_Wrapper is
generic(
	Device_Family		: string := "Cyclone V";
	Num_sThread			: Positive := 4
);
port (
	-- Bucket port sel
	Bucket_PtSel		: in	std_logic; -- '1' outter; '0' inner
	-- Bucket router config
	BucketRt_Config		: in	std_logic; -- high priority
	BucketRt_IncSet		: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	-- Bucket initial
	Bucket_Init			: in	std_logic;
	Bucket_Rdy			: out	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		: in	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	-- Bucket data input and counter increase, port for DAG
	Bucket_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Bucket_Inc			: in	unsigned(Num_sThread-1 downto 0);
	-- Mem addr base and sect
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	-- write index info into memory
	Mem_p2_A			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p2_Do			: out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_p2_Wr			: out	std_logic;
	Mem_p2_Valid		: in	std_logic;
	-- read index from buffer (memory)
	Mem_p4_A			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p4_Rd			: out	std_logic;
	Mem_p4_Di			: in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_p4_RdAck		: in	std_logic;
	Mem_p4_Valid		: in	std_logic;
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
constant cst_BMixExpo		: Natural := Fnc_Int2Wd(Num_sThread-1);
constant cst_mBOffset		: Natural := gcst_mBucket_Offset + cst_BMixExpo;
constant cst_mBWidth		: Natural := gcst_mBucket_Width - cst_mBOffset;

constant cst_mBNum_PerTh	: Natural := gcst_mBucket_Num/Num_sThread;
constant cst_mBRamDeep		: Natural := gcst_mBucket_MaxCap*cst_mBNum_PerTh*2;
constant cst_mBRamAW		: Natural := Fnc_Int2Wd(cst_mBRamDeep-1);

constant cst_UncFIFODeepth	: Natural := 32; --gcst_mBucket_Num
constant cst_UncFIFORsv		: Natural := 6; -- no care lager than 1

constant cst_IdxFIFODeepth	: Natural := 64; --gcst_mBucket_Num
constant cst_IdxFIFORsv		: Natural := 13; --gcst_LpmRam_RtlDL_Rd + 
--										 gcst_AddrAuxCalc_RtlDL + 
--										 gcst_LpmRam_RtlDL_Rd + 
--										 1 + 1 + 1 + -- mux / cmp / sw 
--										 gcst_AddrAuxCalc_RtlDL + 
--										 1 + 1; -- Mux / rsv; 
--										 must lager than 12 

constant cst_MemIdxFIFODW	: Natural := gcst_WD_Mem_Apdix + gcst_WA_Mem;

constant cst_BMixiRamRsv	: Natural := 12;-- gcst_AddrAuxCalc_RtlDL + 
--											1 + -- mux
--											gcst_LpmRam_RtlDL_Rd + 
--											gcst_LpmRam_RtlDL_Rd + 
--											1 + -- / cmp 
--											1; -- state stop lag 9
--======================== Altera component declare ========================--
component altsyncram
generic (
	address_aclr_b				:	string := "NONE";
	address_reg_b				:	string := "CLOCK0";
	clock_enable_input_a		:	string := "BYPASS";
	clock_enable_input_b		:	string := "BYPASS";
	clock_enable_output_b		:	string := "BYPASS";
	intended_device_family		:	string := Device_Family;--"Cyclone V";
	lpm_type					:	string := "altsyncram";
	operation_mode				:	string := "DUAL_PORT";
	outdata_aclr_b				:	string := "NONE";
	outdata_reg_b				:	string := "CLOCK0";
	power_up_uninitialized		:	string := "FALSE";
	read_during_write_mode_mixed_ports	:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a					:	natural := cst_mBRamDeep;
	numwords_b					:	natural := cst_mBRamDeep;
	width_a						:	natural := gcst_WD_Mem;
	width_b						:	natural := gcst_WD_Mem;
	widthad_a					:	natural := cst_mBRamAW; -- log2(x)
	widthad_b					:	natural := cst_mBRamAW; -- log2(x)
	width_byteena_a				:	natural := 1
);
port(
	address_a	:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		:	in std_logic_vector(width_a-1 downto 0);
	wren_a		:	in std_logic;
	
	address_b	:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		:	in std_logic
);
end component;

component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL ;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL ; -- 32
	lpm_widthu					: NATURAL ; -- log2(128)
	almost_full_value 			: Natural ;
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
	almost_full			: out std_logic;

	clock				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;
--===================== user-defined component declare =====================--
component Equihash_GBP_CllsMThread
generic(
	Num_sThread			: Natural := Num_sThread
);
port (
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucketRt_Config	: out	std_logic;
	mBucketRt_IncSet	: out	std_logic; -- '0': p->A; '1': p->B
	mBucketRt_GetSet	: out	std_logic; -- '0': p->A; '1': p->B
	
	mBucket_Init		: out	std_logic;
	mBucket_Rdy			: in	std_logic;
	mBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	mBucket_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	Param_r				: out	Natural range 0 to gcst_Round := 0;
	LastRound			: out	std_logic;
	Mem_AB_Buff_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	: out	Natural range 0 to gcst_N_Chunk-1;
	--MemIdx addr request
	MemIdx_Req			: in	unsigned(Num_sThread-1 downto 0);
	MemIdx_Num			: in	typ_1D_Nat(Num_sThread-1 downto 0);
	MemIdx_Ack			: out	unsigned(Num_sThread-1 downto 0);
	MemIdx_Sub			: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	nxt_St				: out	std_logic;
	nxt_Ed				: in	unsigned(Num_sThread-1 downto 0);
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_CllsSThread
generic(
	Device_Family		: string := Device_Family;
	mBucket_CntDL		: Natural := 0;
	mBucket_Num			: Natural := cst_mBNum_PerTh
);
port (
	AB_MemD_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	Param_r				: in	Natural range 0 to gcst_Round := 0;
	LastRound			: in	std_logic;
	-- to sBucket (outter)
	mBucket_Get			: out	std_logic;
	mBucket_GetIdx		: out	unsigned(gcst_W_Chunk-1 downto 0);
	mBucket_Cnt			: in	Natural range 0 to gcst_mBucket_MaxCap;
	--MemIdx addr request
	MemIdx_Req			: out	std_logic;
	MemIdx_Num			: out	Natural range 0 to gcst_mBucket_MaxCap;
	MemIdx_Ack			: in	std_logic;
	MemIdx_Sub			: in	unsigned(gcst_WA_Mem-1 downto 0);
	-- to sBucket (inner)
	sBucket_ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	sBucket_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	sBucket_Inc			: in	std_logic;
	-- to mBucket (write data)
	mBucket_Di			: out unsigned(gcst_WD_Mem-1 downto 0);
	mBucket_Inc			: out	std_logic;
	mBucket_Valid		: in	std_logic;
	-- read data
	Mem_D_Addr			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_D_Rd			: out	std_logic;
	Mem_D_Valid			: in	std_logic;
	-- write Idx
	Mem_Idx_Addr		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Idx_Wr			: out	std_logic;
	Mem_Idx_Do			: out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_Idx_Valid		: in	std_logic;
	-- info to unc
	InfoLst_AB			: out	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			: out	Natural range 0 to gcst_mBucket_MaxCap;
	InfoLst_Wr			: out	std_logic;
	
	sThEd_Req			: out	std_logic;
	sThEd_Ack			: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_mBucket_Wrapper
generic(
	Device_Family	: string := Device_Family;
	mBucket_Width	: Natural := cst_mBWidth; -- gcst_mBucket_Width - cst_mBOffset;
	mBucket_Offset	: Natural := cst_mBOffset;
	mBucket_Num		: Natural := cst_mBNum_PerTh;
	mBucket_MaxCap	: Natural := gcst_mBucket_MaxCap -- 3*2**9
);
port (
	mB_AB_Buff			: in	unsigned(gcst_WA_Mem-1 downto 0);
	mB_ChunkSel			: in	Natural range 0 to gcst_N_Chunk-1;
	mB_D_i				: in	unsigned(gcst_WD_Mem-1 downto 0);
	mB_Inc				: in	std_logic;
	mB_Init				: in	std_logic;
	mB_Rdy				: out	std_logic;
	mB_Get				: in	std_logic;
	mB_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	mB_Cnt_o			: out	Natural range 0 to mBucket_MaxCap;
	
	Mem_D				: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr				: out	std_logic;
	
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

component Lg_BMix_MidWare
generic(
	NumExpo_Ch_i			: Positive := cst_BMixExpo; -- must lager than NumExpo_Ch_o
	NumExpo_Ch_o			: Positive := cst_BMixExpo;
	InputRsv				: Positive := cst_BMixiRamRsv -- must lager than 4
);
port (
	Data_i		: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i		: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		: in	unsigned(2**NumExpo_Ch_i-1 downto 0);
	Valid_i		: out	unsigned(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		: out	unsigned(2**NumExpo_Ch_o-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	Num				: Positive := Num_sThread;
	Typ				: string := "and"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "true" -- "true" "false"
);
port (
	Di				: in	unsigned(Num-1 downto 0);
	Do				: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_UnCompress
generic(
	Device_Family		: string := Device_Family
);
port (
	AB_MemIdx_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	Mem_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_Di				: in	unsigned(gcst_WD_idxCache-1 downto 0);
	Mem_RdAck			: in	std_logic;
	Mem_Valid			: in	std_logic;
	
	InfoLst_AB			: in	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			: in	Natural;
	InfoLst_Rd			: out	std_logic;
	InfoLst_Emp			: in	std_logic;
	
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
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

component Equihash_GBP_MemIdxMng
generic(
	Num_Ch		: Natural := Num_sThread
);
port (
	DRdy	: in	unsigned(Num_Ch-1 downto 0);
	DRd		: out	unsigned(Num_Ch-1 downto 0);
	Valid	: in	std_logic;
	
	Sel		: out	Natural range 0 to Num_Ch-1;
	
	IdxWr	: out	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;

component Lg_Mux_nL1w_T1
generic(
	Num				: Positive := Num_sThread;
	Syn				: string := "true" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	Sel			: in	Natural;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_SingalPipe
generic(
	Width_D			: Positive;
	Num_Pipe		: Positive
);
port (
	di			: in	unsigned(Width_D-1 downto 0);
	do			: out	unsigned(Width_D-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_SingalPipe_Nat
generic(
	Num_Pipe		: Positive
);
port (
	di		: in	Natural;
	do		: out	Natural;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;
--============================= signal declare =============================--
-- round
signal sgn_r					: Natural range 0 to gcst_Round;
signal sgn_LastRound			: std_logic;
signal sgn_sBucket_ChunkSel		: Natural range 0 to gcst_N_Chunk-1;
-- main control
signal sgn_mBs_ChunkSel			: Natural range 0 to gcst_N_Chunk-1 := 0;
signal sgn_mBs_AB_Buff			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_mBs_Init				: std_logic;
signal sgn_mBs_Rdy				: std_logic;

signal sgn_mBs_Do				: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mBs_Inc				: unsigned(Num_sThread-1 downto 0);

signal sgn_mBt_Do				: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mBt_Inc				: unsigned(Num_sThread-1 downto 0);
-- thread access ram
signal sgn_sB_Di				: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_sB_Inc				: unsigned(Num_sThread-1 downto 0);
signal sgn_sB_Addr				: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal sgn_sB_Rd				: unsigned(Num_sThread-1 downto 0);

type typ_sBtDMux is array (natural range<>, natural range<>) of unsigned(gcst_W_Chunk-1 downto 0);
signal sgn_sBtDMux_i			: typ_sBtDMux(Num_sThread-1 downto 0, gcst_N_Chunk-1 downto 0);

-- mBucket signal
signal sgn_mBs_Config			: std_logic;
signal sgn_mBs_IncSet			: std_logic; -- '0': A->A, B->B; '1': A->B, B->A
signal sgn_mBs_GetSet			: std_logic; -- '0': A->A, B->B; '1': A->B, B->A

signal sgn_mB_Get				: unsigned(Num_sThread-1 downto 0);
type typ_mBGetIdx is array (natural range<>) of unsigned(gcst_W_Chunk-1 downto 0);
signal sgn_mB_GetIdx			: typ_mBGetIdx(Num_sThread-1 downto 0);
signal sgn_mB_GetIdx_Fmt		: typ_mBGetIdx(Num_sThread-1 downto 0);
signal sgn_mB_Cnt_o				: typ_1D_Nat(Num_sThread-1 downto 0);

signal sgn_mB_ChunkSel			: Natural range 0 to gcst_N_Chunk-1 := 0;
signal sgn_mB_AB_Buff			: unsigned(gcst_WA_Mem-1 downto 0);

signal sgn_mB_Init				: std_logic;
signal sgn_mB_Rdy				: unsigned(Num_sThread-1 downto 0); -- for outter

signal sgn_mB_Di				: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mB_Inc				: unsigned(Num_sThread-1 downto 0);

signal sgn_mB_Do				: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mB_A					: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal sgn_mB_Wr				: unsigned(Num_sThread-1 downto 0);

-- bus mix
signal sgn_BMix_Di				: typ_AM_1D_Data(Num_sThread-1 downto 0);
signal sgn_BMix_Ai				: typ_1D_Word(Num_sThread-1 downto 0); -- 0 to Num_Ch_o-1
signal sgn_BMix_Fi				: unsigned(Num_sThread-1 downto 0);
signal sgn_BMix_Valid			: unsigned(Num_sThread-1 downto 0);

signal sgn_BMix_Do				: typ_AM_1D_Data(Num_sThread-1 downto 0);
signal sgn_BMix_Fo				: unsigned(Num_sThread-1 downto 0);

-- thread st and ed
signal sgn_ThSt					: std_logic;
signal sgn_ThEd					: unsigned(Num_sThread-1 downto 0);

-- MemIdx
signal sgn_MemIdx_Req				: unsigned(Num_sThread-1 downto 0);
signal sgn_MemIdx_Num				: typ_1D_Nat(Num_sThread-1 downto 0);
signal sgn_MemIdx_Ack				: unsigned(Num_sThread-1 downto 0);
signal sgn_MemIdx_Sub				: unsigned(gcst_WA_Mem-1 downto 0);

-- mbucekt ram
signal sgn_mBRam_Di					: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_mBRam_AddrWr				: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal sgn_mBRam_Wr					: unsigned(Num_sThread-1 downto 0);
type typ_mBRamDo is array (natural range<>) of std_logic_vector(gcst_WD_Mem-1 downto 0);
signal sgn_mBRam_Do					: typ_mBRamDo(Num_sThread-1 downto 0);
signal sgn_mBRam_AddrRd				: typ_1D_Mem_A(Num_sThread-1 downto 0);

-- thread info output
signal sgn_sThEd_Req				: unsigned(Num_sThread-1 downto 0);
signal sgn_sThEd_Req_M				: unsigned(Num_sThread-1 downto 0);
signal sgn_sThEd_Ack				: unsigned(Num_sThread-1 downto 0);
signal sgn_InfoLst_Sel				: Natural range 0 to Num_sThread-1;
signal sgn_InfoLst_Sel_DL1			: Natural range 0 to Num_sThread-1;
--signal sgn_InfoLst_Sel_DL2		: Natural range 0 to Num_sThread-1;

type typ_InfoLstAB is array (natural range <>) of unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_InfoLstAB				: typ_InfoLstAB(Num_sThread-1 downto 0);
signal sgn_InfoLstNum				: typ_1D_Nat(Num_sThread-1 downto 0);
signal sgn_InfoLstWr				: unsigned(Num_sThread-1 downto 0);

signal sgn_InfoLstAB_Mo				: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_InfoLstNum_Mo			: Natural;
signal sgn_InfoLstWr_Mo				: std_logic;

signal sgn_FIFO_InfoLstAB_Do		: std_logic_vector(gcst_WA_Mem-1 downto 0);
signal sgn_FIFO_InfoLstNum_Do		: std_logic_vector(gcst_WD_mBn-1 downto 0);
signal sgn_FIFO_InfoLstAB_Rd		: std_logic;
signal sgn_FIFO_InfoLstNum_Rd		: std_logic;
signal sgn_FIFO_InfoLst_Emp			: std_logic;
signal sgn_FIFO_InfoLst_Full		: std_logic;

signal sgn_InfoLst_AB				: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_InfoLst_Num				: Natural;
signal sgn_InfoLst_Rd				: std_logic;
signal sgn_InfoLst_Emp				: std_logic;

-- GBP state signal
signal sgn_UnCBsy					: std_logic;
signal sgn_GBPEd					: std_logic;

-- mem read addr base (data)
signal sgn_AB_MemD_Base				: unsigned(gcst_WA_Mem-1 downto 0);

-- Idx fifo
type typ_IdxFifoDi is array (natural range <>) of unsigned(cst_MemIdxFIFODW-1 downto 0);
signal sgn_IdxFifo_Di				: typ_IdxFifoDi(Num_sThread-1 DOWNTO 0);
signal sgn_IdxFifo_Wr				: unsigned(Num_sThread-1 DOWNTO 0);
type typ_IdxFifoDo is array (natural range <>) of STD_LOGIC_VECTOR(cst_MemIdxFIFODW-1 downto 0);
signal sgn_IdxFifo_Do				: typ_IdxFifoDo(Num_sThread-1 DOWNTO 0);
signal sgn_IdxFifo_Rd				: unsigned(Num_sThread-1 DOWNTO 0);
signal sgn_IdxFifo_Emp				: unsigned(Num_sThread-1 DOWNTO 0);
signal sgn_IdxFifo_Full				: unsigned(Num_sThread-1 DOWNTO 0);

signal sgn_MemIdx_A					: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal sgn_MemIdx_Wr				: unsigned(Num_sThread-1 DOWNTO 0);
signal sgn_MemIdx_D					: typ_1D_Idx_D(Num_sThread-1 downto 0);

signal sgn_MemIdx_Sel				: Natural range 0 to Num_sThread-1;
signal sgn_MemIdx_Muxo				: unsigned(cst_MemIdxFIFODW-1 downto 0);
type typ_IdxFifoDo_Fmt is array (natural range <>) of unsigned(Num_sThread-1 downto 0);
signal sgn_IdxFifo_Do_Fmt			: typ_IdxFifoDo_Fmt(cst_MemIdxFIFODW-1 DOWNTO 0);

signal sgn_MemIdx_Wr_M				: std_logic;
signal sgn_r_nxt					: Natural range 0 to gcst_Round-1;

type typ_state is (S_Idle, S_P1, S_P2);
signal state				: typ_state;

-- delay
constant cst_sBRd_DL				: Natural := gcst_LpmRam_RtlDL_Rd; -- 2
signal sgn_sBRd_DL					: unsigned(Num_sThread-1 downto 0);
--
constant cst_MemIdxWrM_DL			: Natural := Fnc_Int2Wd(Num_sThread-1) + 
												1; -- FIFORd +1
signal sgn_MemIdxWrM_DL				: unsigned(0 downto 0);
--
constant cst_MemIdxSel_DL			: Natural := 1; -- FIFORd +1
signal sgn_MemIdxSel_DL				: Natural;
--============================ function declare ============================--

begin

inst01: Equihash_GBP_CllsMThread
port map(
	AB_MemD_BaseA		=> AB_MemD_BaseA,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		=> AB_MemD_BaseB,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucketRt_Config	=> sgn_mBs_Config,--: out	std_logic;
	mBucketRt_IncSet	=> sgn_mBs_IncSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	mBucketRt_GetSet	=> sgn_mBs_GetSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
	
	mBucket_ChunkSel	=> sgn_mBs_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	mBucket_AB_Buff		=> sgn_mBs_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0);

	mBucket_Init		=> sgn_mBs_Init,--: out	std_logic;
	mBucket_Rdy			=> sgn_mBs_Rdy,--: in	std_logic;
	
	Param_r				=> sgn_r,--: out	Natural range 0 to gcst_Round-1 := 0;
	LastRound			=> sgn_LastRound,--: out std_logic;
	Mem_AB_Buff_Rd		=> sgn_AB_MemD_Base,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1;
		--MemIdx addr request
	MemIdx_Req			=> sgn_MemIdx_Req,--: in	unsigned(Num_sThread-1 downto 0);
	MemIdx_Num			=> sgn_MemIdx_Num,--: in	typ_1D_Nat(Num_sThread-1 downto 0);
	MemIdx_Ack			=> sgn_MemIdx_Ack,--: out	unsigned(Num_sThread-1 downto 0);
	MemIdx_Sub			=> sgn_MemIdx_Sub,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	St					=> St,--(io): in	std_logic;
	Ed					=> sgn_GBPEd,--: out	std_logic;
	
	nxt_St				=> sgn_ThSt,--: out	std_logic;
	nxt_Ed				=> sgn_ThEd,--: in	unsigned(Num_sThread-1 downto 0);
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

i0100: for i in 0 to Num_sThread-1 generate
	sgn_mB_GetIdx_Fmt(i)(gcst_W_Chunk-1 downto cst_BMixExpo) <= sgn_mB_GetIdx(i)(gcst_W_Chunk-cst_BMixExpo-1 downto 0);
	sgn_mB_GetIdx_Fmt(i)(cst_BMixExpo-1 downto 0) <= (others => '0');
	
--	sgn_mB_GetIdx_Fmt(i) <= sgn_mB_GetIdx(i) SLL cst_BMixExpo; -- shift 2 bit
	
	inst02: Equihash_mBucket_Wrapper
	port map(
		mB_Init				=> sgn_mB_Init,--: in	std_logic;
		mB_Rdy				=> sgn_mB_Rdy(i),--: out	std_logic;

		mB_AB_Buff			=> sgn_mB_AB_Buff,--: in	unsigned(gcst_WA_Mem-1 downto 0);
		mB_ChunkSel			=> sgn_mB_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;

		mB_D_i				=> sgn_mB_Di(i),--: in	unsigned(gcst_WD_Mem-1 downto 0);
		mB_Inc				=> sgn_mB_Inc(i),--: in	std_logic;

		mB_Get				=> sgn_mB_Get(i),--: in	std_logic;
		mB_GetIdx			=> sgn_mB_GetIdx_Fmt(i),--: in	unsigned(gcst_W_Chunk-1 downto 0);
		mB_Cnt_o			=> sgn_mB_Cnt_o(i),--: out	Natural range 0 to mBucket_MaxCap;
		
		Mem_D				=> sgn_mB_Do(i),--(io): out	unsigned(gcst_WD_Mem-1 downto 0);
		Mem_A				=> sgn_mB_A(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_Wr				=> sgn_mB_Wr(i),--(io): out	std_logic;
		
		M_Config			=> BucketRt_Config,--(io): in	std_logic; -- high priority
		M_IncSet			=> BucketRt_IncSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		M_GetSet			=> BucketRT_GetSet,--(io): in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		
		S_Config			=> sgn_mBs_Config,--: in	std_logic;
		S_IncSet			=> sgn_mBs_IncSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		S_GetSet			=> sgn_mBs_GetSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A
		
		clk					=> clk,--: in	std_logic;
		aclr				=> aclr--: in	std_logic
	);
	
	inst03: Equihash_GBP_CllsSThread
	port map(
		AB_MemD_Base		=> sgn_AB_MemD_Base,--: in	unsigned(gcst_WA_Mem-1 downto 0);
		AB_MemD_Sect		=> AB_MemD_Sect,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
		AB_MemIdx_Base		=> AB_MemIdx_Base,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
		AB_MemIdx_Sect		=> AB_MemIdx_Sect,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
		
		Param_r				=> sgn_r,--: in	Natural range 0 to gcst_Round-1 := 0;
		LastRound			=> sgn_LastRound,--: in	std_logic;
		-- to sBucket (outter)
		mBucket_Get			=> sgn_mB_Get(i),--: out	std_logic;
		mBucket_GetIdx		=> sgn_mB_GetIdx(i),--: out	unsigned(gcst_W_Chunk-1 downto 0);
		mBucket_Cnt			=> sgn_mB_Cnt_o(i),--: in	Natural range 0 to gcst_mBucket_MaxCap;
		--MemIdx addr request
		MemIdx_Req			=> sgn_MemIdx_Req(i),--: out	std_logic;
		MemIdx_Num			=> sgn_MemIdx_Num(i),--: out	Natural range 0 to gcst_mBucket_MaxCap;
		MemIdx_Ack			=> sgn_MemIdx_Ack(i),--: in	std_logic;
		MemIdx_Sub			=> sgn_MemIdx_Sub,--: in	unsigned(gcst_WA_Mem-1 downto 0);
		-- to sBucket (inner)
		sBucket_ChunkSel	=> sgn_sBucket_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1;
		sBucket_Di			=> sgn_sB_Di(i),--: in	unsigned(gcst_WD_Mem-1 downto 0);
		sBucket_Inc			=> sgn_sB_Inc(i),--: in	std_logic;
		-- to mBucket (write data)
		mBucket_Di			=> sgn_mBs_Do(i),--: out unsigned(gcst_WD_Mem-1 downto 0);
		mBucket_Inc			=> sgn_mBs_Inc(i),--: out	std_logic;
		mBucket_Valid		=> sgn_BMix_Valid(i),--(io): in	std_logic;
		-- read data
		Mem_D_Addr			=> sgn_sB_Addr(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_D_Rd			=> sgn_sB_Rd(i),--(io): out	std_logic;
		Mem_D_Valid			=> '1',--(io): in	std_logic;
		-- write Idx
		Mem_Idx_Addr		=> sgn_MemIdx_A(i),--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
		Mem_Idx_Wr			=> sgn_MemIdx_Wr(i),--(io): out	std_logic;
		Mem_Idx_Do			=> sgn_MemIdx_D(i),--(io): out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
		Mem_Idx_Valid		=> (not sgn_IdxFifo_Full(i)),--(io): in	std_logic;
		-- info to unc
		InfoLst_AB			=> sgn_InfoLstAB(i),--: out	unsigned(gcst_WA_Mem-1 downto 0);
		InfoLst_Num			=> sgn_InfoLstNum(i),--: out	Natural range 0 to gcst_mBucket_MaxCap;
		InfoLst_Wr			=> sgn_InfoLstWr(i),--: out	std_logic;
		
		sThEd_Req			=> sgn_sThEd_Req(i),--: out	std_logic;
		sThEd_Ack			=> sgn_sThEd_Ack(i),--: in	std_logic;
		
		St					=> sgn_ThSt,--: in	std_logic;
		Ed					=> sgn_ThEd(i),--: out	std_logic;
		Bsy					=> open,--: out	std_logic;
		
		clk					=> clk,--: in	std_logic;
		aclr				=> aclr--: in	std_logic
	);
	
	inst04:altsyncram
	port map(
		address_a	=> std_logic_vector(sgn_mBRam_AddrWr(i)(cst_mBRamAW-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
		data_a		=> std_logic_vector(sgn_mBRam_Di(i)),--:	in std_logic_vector(width_a-1 downto 0);
		wren_a		=> sgn_mBRam_Wr(i),--:	in std_logic;
		
		address_b	=> std_logic_vector(sgn_mBRam_AddrRd(i)(cst_mBRamAW-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
		q_b			=> sgn_mBRam_Do(i),--:	out std_logic_vector(width_b-1 downto 0);
		
		clock0		=> clk--:	in std_logic
	);
	
	i0110: for j in 0 to gcst_N_Chunk-1 generate
		sgn_sBtDMux_i(i,j) <= sgn_mBt_Do(i)((j+1)*gcst_W_Chunk-1 downto j*gcst_W_Chunk);
	end generate i0110;
	
	process(clk)
	begin
		if(rising_edge(clk))then
			sgn_BMix_Ai(i) <= to_unsigned(0,gcst_WW-cst_BMixExpo) &
							sgn_sBtDMux_i(i,sgn_r_nxt) -- current round + 1
								(gcst_mBucket_Offset + cst_BMixExpo-1 downto gcst_mBucket_Offset);
		end if;
	end process;
	
	-- ram port
	sgn_mBRam_Di(i) <= sgn_mB_Do(i);
	sgn_mBRam_AddrWr(i) <= sgn_mB_A(i);
	sgn_mBRam_Wr(i) <= sgn_mB_Wr(i);
	sgn_mBRam_AddrRd(i) <= sgn_sB_Addr(i);
	sgn_sB_Di(i) <= unsigned(sgn_mBRam_Do(i));
	sgn_sB_Inc(i) <= sgn_sBRd_DL(i);
	
	-- bus mix
	process(clk)
	begin
		if(rising_edge(clk))then
			sgn_BMix_Di(i) <= sgn_mBt_Do(i);
		end if;
	end process;
	sgn_mB_Di(i) <= sgn_BMix_Do(i);
	
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_BMix_Fi(i) <= '0';
		elsif(rising_edge(clk))then
			sgn_BMix_Fi(i) <= sgn_mBt_Inc(i);
		end if;
	end process;
	sgn_mB_Inc(i) <= sgn_BMix_Fo(i);
	
	-- Idx out fifo
	inst11: scfifo -- Idx + Addr
	generic map(
		lpm_numwords		=> cst_IdxFIFODeepth,
		lpm_width			=> cst_MemIdxFIFODW, -- 8
		lpm_widthu			=> Fnc_Int2Wd(cst_IdxFIFODeepth-1), -- log2(128)
		almost_full_value 	=> cst_IdxFIFODeepth - cst_IdxFIFORsv
	)
	port map(
		data				=> std_logic_vector(sgn_IdxFifo_Di(i)),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
		wrreq				=> sgn_IdxFifo_Wr(i),--: IN STD_LOGIC ;

		q					=> sgn_IdxFifo_Do(i),--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
		rdreq				=> sgn_IdxFifo_Rd(i),--: IN STD_LOGIC ;
		
		empty				=> sgn_IdxFifo_Emp(i),--: OUT STD_LOGIC ;
		almost_full			=> sgn_IdxFifo_Full(i),--: out std_logic;
		
		clock				=> clk,--: IN STD_LOGIC ;
		aclr				=> aclr--: IN STD_LOGIC 
	);
	
	-- idx fifo port
	sgn_IdxFifo_Di(i) <= sgn_MemIdx_A(i) & sgn_MemIdx_D(i);
	sgn_IdxFifo_Wr(i) <= sgn_MemIdx_Wr(i);
	
end generate i0100;

sgn_r_nxt <= sgn_mB_ChunkSel;

-- bus mix net
inst05: Lg_BMix_MidWare
port map(
	Data_i		=> sgn_BMix_Di,--: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i		=> sgn_BMix_Ai,--: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		=> sgn_BMix_Fi,--: in	unsigned(2**NumExpo_Ch_i-1 downto 0);
	Valid_i		=> sgn_BMix_Valid,--: out	unsigned(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		=> sgn_BMix_Do,--: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		=> sgn_BMix_Fo,--: out	unsigned(2**NumExpo_Ch_o-1 downto 0);
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- mbucket port
process(clk)
begin
	if(rising_edge(clk))then
		if(Bucket_PtSel='1')then -- outer
			sgn_mB_AB_Buff <= Bucket_AB_Buff;
			sgn_mB_ChunkSel <= Bucket_ChunkSel;
			for i in 0 to Num_sThread-1 loop
				sgn_mBt_Do(i) <= Bucket_Di(i);
			end loop;
		else
			sgn_mB_AB_Buff <= sgn_mBs_AB_Buff;
			sgn_mB_ChunkSel <= sgn_mBs_ChunkSel;
			for i in 0 to Num_sThread-1 loop
				sgn_mBt_Do(i) <= sgn_mBs_Do(i);
			end loop;
		end if;
	end if;
end process;

process(clk, aclr)
begin
	if(aclr='1')then
		sgn_mB_Init <= '0';
		sgn_mBt_Inc <= (others => '0');
	elsif(rising_edge(clk))then
		if(Bucket_PtSel='1')then -- outer
			sgn_mB_Init <= Bucket_Init;
			sgn_mBt_Inc <= Bucket_Inc;
		else
			sgn_mB_Init <= sgn_mBs_Init;
			sgn_mBt_Inc <= sgn_mBs_Inc;
		end if;
	end if;
end process;

-- mBucket ready all and
inst06: Lg_BoolOpt
port map(
	Di			=> sgn_mB_Rdy,--: in	unsigned(Num-1 downto 0);
	Do			=> sgn_mBs_Rdy,--(io): out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

Bucket_Rdy <= sgn_mBs_Rdy;

-- unc part
inst07: Equihash_GBP_UnCompress
port map(
	AB_MemIdx_Base		=> AB_MemIdx_Base,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		=> AB_MemIdx_Sect,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	Mem_A				=> Mem_p4_A,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				=> Mem_p4_Rd,--(io): out	std_logic;
	Mem_Di				=> Mem_p4_Di(gcst_WD_Mem_Apdix-1 downto 0),--(io): in	unsigned(gcst_WD_Idx-1 downto 0);
	Mem_RdAck			=> Mem_p4_RdAck,--(io): in	std_logic;
	Mem_Valid			=> Mem_p4_Valid,--(io): in	std_logic;
	
	InfoLst_AB			=> sgn_InfoLst_AB,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			=> sgn_InfoLst_Num,--: in	Natural;
	InfoLst_Rd			=> sgn_InfoLst_Rd,--: out	std_logic;
	InfoLst_Emp			=> sgn_InfoLst_Emp,--: in	std_logic;
	
	ResValid			=> ResValid,--(io): out	std_logic;
	Res					=> Res,--(io): out	unsigned(gcst_WD_Idx-1 downto 0);
	
	Bsy					=> sgn_UnCBsy,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

-- last round info save
inst08: Lg_Robin_TypI
port map(
	Req				=> sgn_sThEd_Req_M,--: in	unsigned(Robin_Num-1 downto 0);
	Ack				=> sgn_sThEd_Ack,--: out	unsigned(Robin_Num-1 downto 0);
	
	Sel				=> sgn_InfoLst_Sel,--: out	Natural range 0 to Robin_Num-1;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

i0200: for i in 0 to Num_sThread-1 generate
	sgn_sThEd_Req_M(i) <= sgn_sThEd_Req(i) and (not sgn_FIFO_InfoLst_Full);
end generate i0200;

-- sel delay 2clk
process(clk)
begin
	if(rising_edge(clk))then
		sgn_InfoLst_Sel_DL1 <= sgn_InfoLst_Sel;
	end if;
end process;

-- date Mux
process(clk)
begin
	if(rising_edge(clk))then
		sgn_InfoLstAB_Mo <= sgn_InfoLstAB(sgn_InfoLst_Sel_DL1);
		sgn_InfoLstNum_Mo <= sgn_InfoLstNum(sgn_InfoLst_Sel_DL1);
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_InfoLstWr_Mo <= '0';
	elsif(rising_edge(clk))then
		sgn_InfoLstWr_Mo <= sgn_InfoLstWr(sgn_InfoLst_Sel_DL1);
	end if;
end process;

-- fifo
inst09: scfifo -- AB
generic map(
	lpm_numwords		=> cst_UncFIFODeepth,
	lpm_width			=> gcst_WA_Mem, -- 32
	lpm_widthu			=> Fnc_Int2Wd(cst_UncFIFODeepth-1), -- log2(128)
	almost_full_value 	=> cst_UncFIFODeepth - cst_UncFIFORsv
)
port map(
	data				=> std_logic_vector(sgn_InfoLstAB_Mo),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_InfoLstWr_Mo,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_InfoLstAB_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_InfoLstAB_Rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_FIFO_InfoLst_Emp,--: OUT STD_LOGIC ;
	almost_full			=> sgn_FIFO_InfoLst_Full,--: out std_logic;
	
	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst10: scfifo -- Num
generic map(
	lpm_numwords		=> cst_UncFIFODeepth,
	lpm_width			=> gcst_WD_mBn, -- 8
	lpm_widthu			=> Fnc_Int2Wd(cst_UncFIFODeepth-1), -- log2(128)
	almost_full_value 	=> cst_UncFIFODeepth - cst_UncFIFORsv
)
port map(
	data				=> std_logic_vector(to_unsigned(sgn_InfoLstNum_Mo,gcst_WD_mBn)),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_InfoLstWr_Mo,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_InfoLstNum_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_InfoLstNum_Rd,--: IN STD_LOGIC ;
	
	empty				=> open,--: OUT STD_LOGIC ;
	almost_full			=> open,--: out std_logic;
	
	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_FIFO_InfoLstAB_Rd <= sgn_InfoLst_Rd;
sgn_FIFO_InfoLstNum_Rd <= sgn_InfoLst_Rd;
sgn_InfoLst_Emp <= sgn_FIFO_InfoLst_Emp;
sgn_InfoLst_AB <= unsigned(sgn_FIFO_InfoLstAB_Do);
sgn_InfoLst_Num <= to_integer(unsigned(sgn_FIFO_InfoLstNum_Do));

-- mem idx read control and mux

inst12: Equihash_GBP_MemIdxMng
port map(
	DRdy	=> (not sgn_IdxFifo_Emp),--: in	unsigned(Num_Ch-1 downto 0);
	DRd		=> sgn_IdxFifo_Rd,--: out	unsigned(Num_Ch-1 downto 0);
	Valid	=> Mem_p2_Valid,--: in	std_logic;
	
	Sel		=> sgn_MemIdx_Sel,--: out	Natural range 0 to Num_Ch-1;
	
	IdxWr	=> sgn_MemIdx_Wr_M,--: out	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

i0300: for i in 0 to cst_MemIdxFIFODW-1 generate
	i0310: for j in 0 to Num_sThread-1 generate
		sgn_IdxFifo_Do_Fmt(i)(j) <= sgn_IdxFifo_Do(j)(i);
	end generate i0310;
	inst13: Lg_Mux_nL1w_T1
	port map(
		Di			=> sgn_IdxFifo_Do_Fmt(i),--: in	unsigned(Num-1 downto 0);
		Do			=> sgn_MemIdx_Muxo(i),--: out	std_logic;
		Sel			=> sgn_MemIdxSel_DL,--: in	Natural;
		
		clk			=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0300;

Mem_p2_Do <= sgn_MemIdx_Muxo(gcst_WD_Mem_Apdix-1 downto 0);
Mem_p2_A <= sgn_MemIdx_Muxo(cst_MemIdxFIFODW-1 downto gcst_WD_Mem_Apdix);
Mem_p2_Wr <= sgn_MemIdxWrM_DL(0);

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

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => Num_sThread, Num_Pipe => cst_sBRd_DL)
port map(di => sgn_sB_Rd, do => sgn_sBRd_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemIdxWrM_DL)
port map(di => Fnc_STD2U0(sgn_MemIdx_Wr_M), do => sgn_MemIdxWrM_DL, clk => clk, aclr => aclr);
--
instPP03: Lg_SingalPipe_Nat
generic map(Num_Pipe => cst_MemIdxSel_DL)
port map(di => sgn_MemIdx_Sel, do => sgn_MemIdxSel_DL, clk => clk, aclr => '0');


end rtl;
