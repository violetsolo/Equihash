----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsSThread - Behavioral
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

entity Equihash_GBP_CllsSThread is
generic(
	Device_Family		: string := "Cyclone V";
	mBucket_Num			: Natural := 2**12;
	mBucket_MaxCap		: Natural := 2**11; -- 3*2**9
	sBucket_Width		: Natural := 8;
	sBucket_Offset		: Natural := 12;
	sBucket_Num			: Natural := 2**8;
	sBucket_MaxCap		: Natural := 17--2**5 -- 17
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
	
	Param_r				: in	Natural range 0 to gcst_Round := 0;
	
	Stp4_IdxReqNum		: out	Natural;
	Stp4_IdxReq		: out	std_logic;
	Stp4_IdxAckVal		: in	Natural;
	Stp4_IdxAck		: in	std_logic;
	
	Stp5_IdxReqNum		: out	Natural;
	Stp5_IdxReq		: out	std_logic;
	Stp5_IdxAckVal		: in	Natural;
	Stp5_IdxAck		: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsSThread;

architecture rtl of Equihash_GBP_CllsSThread is
--============================ constant declare ============================--
constant cst_Cache_Deepth		: Natural := sBucket_MaxCap * sBucket_Num;
constant cst_Cache_ExpoDeepth	: Natural := Fnc_Int2Wd(cst_Cache_Deepth-1);

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
	numwords_a					:	natural := cst_Cache_Deepth;
	numwords_b					:	natural := cst_Cache_Deepth;
	width_a						:	natural;
	width_b						:	natural;
	widthad_a					:	natural := cst_Cache_ExpoDeepth; -- log2(x)
	widthad_b					:	natural := cst_Cache_ExpoDeepth; -- log2(x)
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

--===================== user-defined component declare =====================--

component Equihash_GBP_CllsStp3
generic(
	sBucket_Width	: Natural := sBucket_Width;
	sBucket_Offset	: Natural := sBucket_Offset;
	sBucket_Num		: Natural := sBucket_Num;
	sBucket_MaxCap	: Natural := sBucket_MaxCap -- 17
);
port (
	sBucket_Get		: out	std_logic;
	sBucket_GetIdx	: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	sBucket_Cnt		: in	Natural range 0 to sBucket_MaxCap;
	
	sBucket_Init	: out	std_logic;
	sBucket_Rdy		: in	std_logic;
	
	Acc_Clr			: out	std_logic;
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_p			: out	Natural range 0 to sBucket_Num-1 := 0; -- hold during process
	Param_sBn		: out	Natural range 0 to sBucket_MaxCap := 0; -- hold during process
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_CllsStp4
generic(
	sBucket_MaxCap	: Natural := sBucket_MaxCap -- 17
);
port (
	Mem_Addr_j		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr			: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Addr_j	: out	unsigned(gcst_WA_Cache-1 downto 0); -- hold 2clk every time
	Cache_Idx		: out	unsigned(gcst_WD_Cache_Apdix - 1 downto 0); -- 24bit Accm value and 8bit 0s  -- 1clk delay after Cache_Addr_j output
	Cache_IdxWr		: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	Acc_Clr			: in	std_logic;
	
	IdxReqNum		: out	Natural;
	IdxReq			: out	std_logic;
	IdxAckVal		: in	Natural;
	IdxAck			: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to sBucket_MaxCap;
	
	nxt_St			: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_CllsStp5
generic(
	sBucket_MaxCap	: Natural := sBucket_MaxCap -- 17
);
port (
	Cache_Addr_j	: out	unsigned(gcst_WA_Cache-1 downto 0);
	Cache_Stp		: out	unsigned(gcst_WD_Cache_Stp-1 downto 0);
	
	LastRound		: in	std_logic;
	
	mC_Latch		: out	std_logic;
	
	mBucket_Inc		: out	std_logic;
	
	Mem_Wr			: out	std_logic;
	Mem_Addr_j		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	IdxReqNum		: out	Natural;
	IdxReq			: out	std_logic;
	IdxAckVal		: in	Natural;
	IdxAck			: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to sBucket_MaxCap;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_AddrAuxCalc
generic(
	Width_A		: Natural
);
port (
	AB_M			: in	unsigned(Width_A-1 downto 0);
	AB_S			: in	unsigned(Width_A-1 downto 0);
	
	Idx				: in	unsigned(Width_A-1 downto 0);
	Sect			: in	unsigned(Width_A-1 downto 0);
	
	A_o				: out	unsigned(Width_A-1 downto 0);
	
	clk				: in	std_logic
);
end component;

component Equihash_BucketDisp
generic(
	Device_Family	: string := Device_Family;
	Width_Addr		: Natural := gcst_WA_Cache;
	Bucket_Width	: Natural := sBucket_Width;
	Bucket_Offset	: Natural := sBucket_Offset;
	Bucket_Num		: Natural := sBucket_Num;
	Bucket_MaxCap	: Natural := sBucket_MaxCap -- 3*2**9
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
--============================= signal declare =============================--
-- cache
signal sgn_Cache_Apdix_Di		: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_Cache_Apdix_Do		: std_logic_vector(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_Cache_Apdix_Addr		: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_Cache_Apdix_Wr		: std_logic;

signal sgn_Cache_Data_Di		: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_Cache_Data_Do		: std_logic_vector(gcst_WD_Cache_Data-1 downto 0);
signal sgn_Cache_Data_Addr		: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_Cache_Data_Wr		: std_logic;
-- st and end chain
signal sgn_St_Stp3_Stp4			: std_logic;
signal sgn_St_Stp4_Stp5			: std_logic;

signal sgn_Ed_Stp5_Stp3			: std_logic;

-- param
-- from stp3
signal sgn_p					: Natural range 0 to sBucket_Num-1;
signal sgn_sBn					: Natural range 0 to sBucket_MaxCap;
-- from stp4
signal sgn_Stp4MemAj			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_Stp4CacheAj			: unsigned(gcst_WA_Cache-1 downto 0); 
-- from stp5
signal sgn_Stp5MemAj			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_Stp5CacheAj			: unsigned(gcst_WA_Cache-1 downto 0);
-- from mux
signal sgn_j					: unsigned(gcst_WA_Cache-1 downto 0);

-- sBucket
signal sgn_sBucket_Init			: std_logic;
signal sgn_sBucket_Rdy			: std_logic;
signal sgn_sBucket_ChunkSel		: Natural range 0 to gcst_N_Chunk-1;
signal sgn_sBucket_Get			: std_logic;
signal sgn_sBucket_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
signal sgn_sBucket_Cnt			: Natural range 0 to sBucket_MaxCap;

signal sgn_sBucketD				: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_sBucketA				: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_sBucketWr			: std_logic;

-- stp3
signal sgn_Stp3ChSel			: std_logic;
signal sgn_Stp3AccClr			: std_logic;

-- stp4
signal sgn_Stp4MemAddr			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_Stp4MemWr			: std_logic;
signal sgn_Stp4MemDo			: unsigned(gcst_WD_Mem_Apdix-1 downto 0);

signal sgn_Stp4CacheSel			: std_logic;
signal sgn_Stp4CacheIdx			: unsigned(gcst_WD_Cache_Apdix - 1 downto 0);
signal sgn_Stp4CacheIdxWr		: std_logic;

signal sgn_Stp4MuxIdx			: unsigned(gcst_WD_Cache_Apdix - 1 downto 0);
signal sgn_Stp4MuxIdxWr			: std_logic;
signal sgn_Stp4MuxAddr			: unsigned(gcst_WA_Cache - 1 downto 0);
signal sgn_Stp4MuxData			: unsigned(gcst_WD_Cache_Data - 1 downto 0);
signal sgn_Stp4MuxDataWr		: std_logic;

signal sgn_Stp4CacheAddr		: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_Param_r				: Natural range 0 to gcst_Round;

-- stp5
signal sgn_Stp5Latch			: std_logic;
signal sgn_Stp5CacheStp			: unsigned(gcst_WD_Cache_Stp-1 downto 0); -- 8
signal sgn_Stp5Inc				: std_logic;
signal sgn_mCollision			: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_xCollision			: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_xApdix				: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_xApdix_DL			: unsigned(gcst_WD_Cache_Apdix-1 downto 0);

signal sgn_Stp5MemWr			: std_logic;

signal sgn_MemAj				: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemAddr				: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemWr				: std_logic;

signal sgn_Cmp					: std_logic;

-- delay
constant cst_MemAddr_DL			: Natural := gcst_LpmRam_RtlDL_Wr + 
											gcst_AddrAuxCalc_RtlDL + 
											1 + 1 - 
											gcst_AddrAuxCalc_RtlDL - 
											1 + 1; -- 4
signal sgn_MemAddr_DL			: unsigned(gcst_WA_Mem-1 downto 0);
-- 
constant cst_MemWr_DL			: Natural := gcst_LpmRam_RtlDL_Wr + 
											 gcst_AddrAuxCalc_RtlDL + 
											 1 + 1 - 
											 1 + 1; -- 6
signal sgn_MemWr_DL				: unsigned(0 downto 0);
--
constant cst_Stp4CacheIdx_DL	: Natural := gcst_AddrAuxCalc_RtlDL + 1; -- 3
signal sgn_Stp4CacheIdx_DL		: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
-- 
constant cst_Stp4CacheIdxWr_DL	: Natural := gcst_AddrAuxCalc_RtlDL + 1; -- 3
signal sgn_Stp4CacheIdxWr_DL	: unsigned(0 downto 0);														 
--
constant cst_Stp5Latch_DL		: Natural := gcst_AddrAuxCalc_RtlDL + 
											 gcst_LpmRam_RtlDL_Wr + 1 + 1; -- 6
signal sgn_Stp5Latch_DL			: unsigned(0 downto 0);
--
constant cst_Stp5CacheStp_DL	: Natural := gcst_LpmRam_RtlDL_Wr + 
											 gcst_AddrAuxCalc_RtlDL + 
											 1 + 1; -- 6
signal sgn_Stp5CacheStp_DL		: unsigned(gcst_WD_Cache_Stp-1 downto 0);
signal sgn_Stp5CacheStp_DL1		: unsigned(gcst_WD_Cache_Stp-1 downto 0);
--
constant cst_Stp5Inc_DL			: Natural := gcst_LpmRam_RtlDL_Wr + 
											 gcst_AddrAuxCalc_RtlDL + 
											 1 + 1 + 1; -- 7
signal sgn_Stp5Inc_DL			: unsigned(0 downto 0);

--============================ function declare ============================--

begin

inst03: Equihash_GBP_CllsStp3
port map(
	sBucket_Get		=> sgn_sBucket_Get,--: out	std_logic;
	sBucket_GetIdx	=> sgn_sBucket_GetIdx,--: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	sBucket_Cnt		=> sgn_sBucket_Cnt,--: in	Natural range 0 to sBucket_MaxCap;
	
	sBucket_Init	=> sgn_sBucket_Init,--: out	std_logic;
	sBucket_Rdy		=> sgn_sBucket_Rdy,--: in	std_logic;
	
	Acc_Clr			=> sgn_Stp3AccClr,--: out	std_logic;
	Cache_Sel		=> sgn_Stp3ChSel,--: out	std_logic; -- '1' current sm get control right
	
	St				=> St,--: in	std_logic;
	Ed				=> Ed,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	Param_p			=> sgn_p,--: out	Natural range 0 to sBucket_Num-1 := 0; -- hold during process
	Param_sBn		=> sgn_sBn,--: out	Natural range 0 to sBucket_MaxCap := 0; -- hold during process
	
	nxt_St			=> sgn_St_Stp3_Stp4,--: out	std_logic;
	nxt_Ed			=> sgn_Ed_Stp5_Stp3,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst04: Equihash_GBP_CllsStp4
port map(
	Mem_Addr_j		=> sgn_Stp4MemAj,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Wr			=> sgn_Stp4MemWr,--: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Addr_j	=> sgn_Stp4CacheAj,--: out	unsigned(gcst_WA_Cache-1 downto 0); -- hold 2clk every time
	Cache_Idx		=> sgn_Stp4CacheIdx,--: out	unsigned(gcst_WD_Cache_Apdix - 1 downto 0); -- 24bit Accm value and 8bit 0s  -- 1clk delay after Cache_Addr_j output
	Cache_IdxWr		=> sgn_Stp4CacheIdxWr,--: out	std_logic; -- 1clk delay after Cache_Addr_j output
	
	Cache_Sel		=> sgn_Stp4CacheSel,--: out	std_logic; -- '1' current sm get control right
	Acc_Clr			=> sgn_Stp3AccClr,--: in	std_logic;
	
	IdxReqNum		=> Stp4_IdxReqNum,--(io): out	Natural;
	IdxReq			=> Stp4_IdxReq,--(io): out	std_logic;
	IdxAckVal		=> Stp4_IdxAckVal,--(io): in	Natural;
	IdxAck			=> Stp4_IdxAck,--(io): in	std_logic;
	
	St				=> sgn_St_Stp3_Stp4,--: in	std_logic;
	Ed				=> open,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	Param_sBn		=> sgn_sBn,--: in	Natural range 0 to sBucket_MaxCap;
	
	nxt_St			=> sgn_St_Stp4_Stp5,--: out	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst05: Equihash_GBP_CllsStp5
port map(
	Cache_Addr_j	=> sgn_Stp5CacheAj,--: out	unsigned(gcst_WA_Cache-1 downto 0);
	Cache_Stp		=> sgn_Stp5CacheStp,--: out	unsigned(gcst_WD_Cache_Stp-1 downto 0);
	
	LastRound		=> LastRound,--: in	std_logic;
	
	mC_Latch		=> sgn_Stp5Latch,--: out	std_logic;
	
	mBucket_Inc		=> sgn_Stp5Inc,--: out	std_logic;
	
	Mem_Wr			=> sgn_Stp5MemWr,--: out	std_logic;
	Mem_Addr_j		=> sgn_Stp5MemAj,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	IdxReqNum		=> Stp5_IdxReqNum,--(io): out	Natural;
	IdxReq			=> Stp5_IdxReq,--(io): out	std_logic;
	IdxAckVal		=> Stp5_IdxAckVal,--(io): in	Natural;
	IdxAck			=> Stp5_IdxAck,--(io): in	std_logic;
	
	St				=> sgn_St_Stp4_Stp5,--: in	std_logic;
	Ed				=> sgn_Ed_Stp5_Stp3,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	Param_sBn		=> sgn_sBn,--: in	Natural range 0 to sBucket_MaxCap;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst06: Equihash_BucketDisp
port map(
	AB_Bucket	=> gcst_sBucket_Sect,--(const): in	unsigned(Width_Addr-1 downto 0); -- 0
	AB_Buff		=> gcst_AB_Cache,--: in	unsigned(Width_Addr-1 downto 0);

	D_i			=> sBucket_Di,--(io): in	unsigned(gcst_WD_Mem-1 downto 0);
	ChunkSel	=> sBucket_ChunkSel,--(io): in	Natural range 0 to gcst_N_Chunk-1;
	Inc			=> sBucket_Inc,--(io): in	std_logic;
			
	Mem_D		=> sgn_sBucketD,--: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A		=> sgn_sBucketA,--: out	unsigned(Width_Addr-1 downto 0);
	Mem_Wr		=> sgn_sBucketWr,--: out	std_logic;
	
	Get			=> sgn_sBucket_Get,--: in	std_logic;
	GetIdx		=> sgn_sBucket_GetIdx,--: in	unsigned(gcst_W_Chunk-1 downto 0); -- heed: value locate at Bucket_Offset+Fnc_Int2Wd(Bucket_Num-1)-1 downto Bucket_Offset
	Cnt_o		=> sgn_sBucket_Cnt,--: out	Natural range 0 to Bucket_MaxCap;
	
	Init		=> sgn_sBucket_Init,--: in	std_logic;
	Rdy			=> sgn_sBucket_Rdy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic := '0'
);

-- ram for data
inst07: altsyncram
generic map(
	width_a		=> gcst_WD_Cache_Data,--:	natural;
	width_b		=> gcst_WD_Cache_Data--:	natural
)
port map(
	address_a	=> std_logic_vector(sgn_Cache_Data_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> std_logic_vector(sgn_Cache_Data_Di),--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Cache_Data_Wr,--:	in std_logic;
	
	address_b	=> std_logic_vector(sgn_Cache_Data_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Cache_Data_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- ram for Idx
inst08: altsyncram
generic map(
	width_a		=> gcst_WD_Cache_Apdix,--:	natural;
	width_b		=> gcst_WD_Cache_Apdix--:	natural
)
port map(
	address_a	=> std_logic_vector(sgn_Cache_Apdix_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> std_logic_vector(sgn_Cache_Apdix_Di),--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Cache_Apdix_Wr,--:	in std_logic;
	
	address_b	=> std_logic_vector(sgn_Cache_Apdix_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Cache_Apdix_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- step 4 part
-- Mem_Aj and wr sel
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp4CacheSel = '1')then
			sgn_MemAj <= sgn_Stp4MemAj;
			sgn_MemWr <= sgn_Stp4MemWr;
		else
			sgn_MemAj <= sgn_Stp5MemAj;
			sgn_MemWr <= sgn_Stp5MemWr;
		end if;
	end if;
end process;

-- write Indx to Mem signals gen
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp4CacheSel = '1')then
			sgn_Param_r <= Param_r;
		else
			sgn_Param_r <= Param_r + 1;
		end if;
	end if;
end process;

inst10: Equihash_AddrAuxCalc
generic map(
	Width_A			=> gcst_WA_Mem--: Natural 32
)
port map(
	AB_M			=> gcst_AB_MemIdx,--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> gcst_AB_MemIdx_Sect,--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> sgn_MemAj,--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_Param_r,gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> sgn_MemAddr,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

Mem_Addr <= sgn_MemAddr_DL;
Mem_Wr <= sgn_MemWr_DL(0);
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp4CacheSel = '1')then
			Mem_Do <= unsigned(sgn_Cache_Apdix_Do);
		else
			if(sgn_Cmp='0')then
				Mem_Do <= to_unsigned(0,gcst_WD_Cache_Stp) & -- 8bit step value
						unsigned(sgn_xApdix(gcst_WD_Cache_Idx-1 downto 0)); -- 24bit latched value
			else
				Mem_Do <= sgn_Stp5CacheStp_DL & -- 8bit step value
						unsigned(sgn_xApdix(gcst_WD_Cache_Idx-1 downto 0)); -- 24bit latched value
			end if;
		end if;
	end if;
end process;

-- write Indx to Cache signals gen
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp4CacheSel = '1')then
			sgn_j <= sgn_Stp4CacheAj;
		else
			sgn_j <= sgn_Stp5CacheAj;
		end if;
	end if;
end process;

-- calculate addr
inst11: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Cache--: Natural 32
)
port map(
	AB_M			=> gcst_AB_Cache,--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> gcst_sBucket_Sect,--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> sgn_j,--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_p,gcst_WA_Cache),--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> sgn_Stp4CacheAddr,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

-- mux addr data and wr signals
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp3ChSel = '1')then -- data from this module
			sgn_Stp4MuxIdx <= sgn_sBucketD(gcst_WD_Mem-1 downto gcst_WD_Mem-gcst_WD_Cache_Apdix); -- last 32bit
			sgn_Stp4MuxIdxWr <= sgn_sBucketWr;
			sgn_Stp4MuxAddr <= sgn_sBucketA;
			sgn_Stp4MuxDataWr <= sgn_sBucketWr;
		else -- data from this outter
			sgn_Stp4MuxIdx <= sgn_Stp4CacheIdx_DL; -- 
			sgn_Stp4MuxIdxWr <= sgn_Stp4CacheIdxWr_DL(0);
			sgn_Stp4MuxAddr <= sgn_Stp4CacheAddr;
			sgn_Stp4MuxDataWr <= '0';
		end if;
		sgn_Stp4MuxData <= sgn_sBucketD(gcst_WD_Cache_Data-1 downto 0); -- delay first 200bit
	end if;
end process;

-- connect to ram
sgn_Cache_Apdix_Di		<= sgn_Stp4MuxIdx;
sgn_Cache_Apdix_Addr	<= sgn_Stp4MuxAddr;
sgn_Cache_Apdix_Wr		<= sgn_Stp4MuxIdxWr;

sgn_Cache_Data_Di		<= sgn_Stp4MuxData;
sgn_Cache_Data_Addr		<= sgn_Stp4MuxAddr;
sgn_Cache_Data_Wr		<= sgn_Stp4MuxDataWr;

-- step 5
-- data latch
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp5Latch_DL(0) = '1')then
			sgn_mCollision <= unsigned(sgn_Cache_Data_Do);
			sgn_xApdix <= unsigned(sgn_Cache_Apdix_Do);
		end if;
	end if;
end process;

-- xor
process(clk)
begin
	if(rising_edge(clk))then
		sgn_xCollision <= sgn_mCollision xor unsigned(sgn_Cache_Data_Do);
		sgn_xApdix_DL <= sgn_xApdix;
	end if;
end process;

-- compare
--sgn_Cmp <= '1' when sgn_mCollision(gcst_N_Chunk*gcst_W_Chunk-1 downto (gcst_N_Chunk-1)*gcst_W_Chunk-1) = 
--					unsigned(sgn_Cache_Data_Do(gcst_N_Chunk*gcst_W_Chunk-1 downto (gcst_N_Chunk-1)*gcst_W_Chunk-1))
--				else 
--			'0';-- last 20bit
sgn_Cmp <= '1' when sgn_mCollision = unsigned(sgn_Cache_Data_Do) else 
			'0';-- last 20bit

-- write mem signal gen (to mBucket)
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Stp5CacheStp_DL1 <= sgn_Stp5CacheStp_DL; -- delay 1clk
	end if;
end process;
mBucket_Di <= sgn_Stp5CacheStp_DL1 & -- 255~248(8bit)
			  unsigned(sgn_xApdix_DL(gcst_WD_Cache_Idx-1 downto 0)) & -- 247~224(24bit)
			  to_unsigned(0, gcst_WD_Mem-gcst_WD_Cache_Data-gcst_WD_Cache_Apdix) & -- 223~200(24bit)
			  sgn_xCollision; -- 199~0(200bit)
mBucket_Inc <= sgn_Stp5Inc_DL(0);

-- delay
instPP03: Lg_SingalPipe
generic map(Width_D => gcst_WA_Mem, Num_Pipe => cst_MemAddr_DL)
port map(di => sgn_MemAddr, do => sgn_MemAddr_DL, clk => clk, aclr => '0');
--
instPP04: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemWr_DL)
port map(di => Fnc_STD2U0(sgn_MemWr), do => sgn_MemWr_DL, clk => clk, aclr => aclr);
--
instPP05: Lg_SingalPipe
generic map(Width_D => gcst_WA_Mem, Num_Pipe => cst_Stp4CacheIdx_DL)
port map(di => sgn_Stp4CacheIdx, do => sgn_Stp4CacheIdx_DL, clk => clk, aclr => '0');
--
instPP06: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp4CacheIdxWr_DL)
port map(di => Fnc_STD2U0(sgn_Stp4CacheIdxWr), do => sgn_Stp4CacheIdxWr_DL, clk => clk, aclr => aclr);
--
instPP07: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp5Latch_DL)
port map(di => Fnc_STD2U0(sgn_Stp5Latch), do => sgn_Stp5Latch_DL, clk => clk, aclr => aclr);
--
instPP08: Lg_SingalPipe
generic map(Width_D => gcst_WD_Cache_Stp, Num_Pipe => cst_Stp5CacheStp_DL)
port map(di => sgn_Stp5CacheStp, do => sgn_Stp5CacheStp_DL, clk => clk, aclr => '0');
--
instPP09: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp5Inc_DL)
port map(di => Fnc_STD2U0(sgn_Stp5Inc), do => sgn_Stp5Inc_DL, clk => clk, aclr => aclr);


end rtl;

