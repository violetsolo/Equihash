----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/07/2018 
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
	Device_Family		: string := "Cyclone V"
);
port (
	Param_r				: in	Natural range 0 to gcst_Round := 0;
	Mem_D_AB			: in	unsigned(gcst_WA_Mem-1 downto 0);
	LastRound			: in	std_logic;
	-- thread task and param
	FIFO_Tsk_Di			: in	typ_ThTsk;
	FIFO_Tsk_Wr			: in	std_logic;
	FIFO_Tsk_Full		: out	std_logic;
	FIFO_Tsk_Emp		: out	std_logic;
	-- to sBucket (inner)
	sBucket_ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	sBucket_Di			: in	unsigned(gcst_WD_Mem-1 downto 0);
	sBucket_Inc			: in	std_logic;
	-- to mBucket (write data)
	mBucket_Di			: out	unsigned(gcst_WD_Mem-1 downto 0);
	mBucket_Inc			: out	std_logic;
	-- read data
	Mem_D_Addr			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_D_Rd			: out	std_logic;
	-- write Idx
	Mem_Idx_Addr		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Idx_Wr			: out	std_logic;
	Mem_Idx_Do			: out	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	-- info to unc
	InfoLst_AB			: out	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			: out	Natural range 0 to gcst_mBucket_MaxCap;
	InfoLst_Wr			: out	std_logic;
	
	sThEd_Req			: out	std_logic;
	sThEd_Ack			: in	std_logic;
	
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsSThread;

architecture rtl of Equihash_GBP_CllsSThread is
--============================ constant declare ============================--
constant cst_Cache_Deepth		: Natural := gcst_sBucket_MaxCap * gcst_sBucket_Num;
constant cst_Cache_ExpoDeepth	: Natural := Fnc_Int2Wd(cst_Cache_Deepth-1);

constant cst_CacheD_Deepth		: Natural := gcst_mBucket_MaxCap;
constant cst_CacheD_ExpoDeepth	: Natural := Fnc_Int2Wd(cst_CacheD_Deepth-1);

constant cst_FIFOTsk4_Deepth		: Natural := 32;
constant cst_FIFOTsk4_rem			: Natural := 5;
constant cst_FIFOTsk4_DW			: Natural := gcst_WD_sBn+gcst_WD_ParamP;

constant cst_FIFOTsk2_Deepth	: Natural := 32;
constant cst_FIFOTsk2_rem		: Natural := 5;
constant cst_FIFOTsk2_DW		: Natural := gcst_WD_mBn+gcst_WD_ParamQ+gcst_WA_Mem;
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

component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL;
	lpm_widthu					: NATURAL; -- log2(128)
	almost_full_value 			: Natural;
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
component Equihash_GBP_CllsStp2
port (
	mBn				: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	FIFO_Rd			: out	std_logic;
	FIFO_Emp		: in	std_logic;
	
	Mem_Addr_i		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			: out	std_logic;
	Mem_RdBsy		: in	std_logic;
	
	AccRst			: out	std_logic;
	
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_CllsStp3
generic(
	Device_Family	: string := Device_Family
);
port (
	sBucket_Init	: out	std_logic;
	sBucket_Rdy		: in	std_logic;
	
	sBucket_Get		: out	std_logic;
	sBucket_GetIdx	: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	SBucket_Cnt		: in	Natural range 0 to gcst_sBucket_MaxCap;
	
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	Acc_Clr			: out	std_logic;
	
	LastRound		: in	std_logic;
	
	Buff_P_D		: out	unsigned(gcst_WD_sBn+gcst_WD_ParamP-1 downto 0);
	Buff_P_Wr		: out	std_logic;
	Buff_P_Full		: in	std_logic;
	Buff_P_Emp		: in	std_logic;
	
	ThEd_Req		: out	std_logic;
	ThEd_Ack		: in	std_logic;
	InfoLst_Wr		: out	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Tsk_Bsy			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_CllsStp4
port (
	LastRound		: in	std_logic;
	
	Param_jk		: out	Natural;
	
	Mem_Wr			: out	std_logic;
	mBucket_Inc		: out	std_logic;
	Mem_Sel			: out	std_logic;
	
	mC_Latch		: out	std_logic;
	Acc_Inc			: out	std_logic;
	
	Buff_P_Rd		: out	std_logic;
	Buff_P_Emp		: in	std_logic;
	
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to gcst_sBucket_MaxCap;
	
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
	TypCounter		: string := "Arr"; --"Ram" or "Arr"
	Width_Addr		: Natural := gcst_WA_Cache;
	Bucket_Width	: Natural := gcst_sBucket_Width;
	Bucket_Offset	: Natural := gcst_sBucket_Offset;
	Bucket_Num		: Natural := gcst_sBucket_Num;
	Bucket_MaxCap	: Natural := gcst_sBucket_MaxCap -- 3*2**9
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
-- cache
signal sgn_Cache_Apdix_Di		: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_Cache_Apdix_Do		: std_logic_vector(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_Cache_Apdix_Addr		: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_Cache_Apdix_Wr		: std_logic;

signal sgn_Cache_DataIdx_Di		: unsigned(cst_CacheD_ExpoDeepth-1 downto 0);
signal sgn_Cache_DataIdx_Do		: std_logic_vector(cst_CacheD_ExpoDeepth-1 downto 0);
signal sgn_Cache_DataIdx_Addr	: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_Cache_DataIdx_Wr		: std_logic;

signal sgn_Cache_Data_Di		: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_Cache_Data_Do		: std_logic_vector(gcst_WD_Cache_Data-1 downto 0);
signal sgn_Cache_Data_AddrRd	: unsigned(cst_CacheD_ExpoDeepth-1 downto 0);
signal sgn_Cache_Data_AddrWr	: unsigned(cst_CacheD_ExpoDeepth-1 downto 0);
signal sgn_Cache_Data_Wr		: std_logic;

-- sBucket
signal sgn_sBucket_Init			: std_logic;
signal sgn_sBucket_Rdy			: std_logic;
signal sgn_sBucket_Get			: std_logic;
signal sgn_sBucket_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
signal sgn_sBucket_Cnt			: Natural range 0 to gcst_sBucket_MaxCap;

signal sgn_sBucketD				: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_sBucketA				: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_sBucketWr			: std_logic;

-- task fifo (to stp4)
signal sgn_Fifo_Tsk4_Di			: unsigned(cst_FIFOTsk4_DW-1 downto 0);
signal sgn_Fifo_Tsk4_Do			: std_logic_vector(cst_FIFOTsk4_DW-1 downto 0);
signal sgn_Fifo_Tsk4_Rd			: std_logic;
signal sgn_Fifo_Tsk4_Wr			: std_logic;
signal sgn_Fifo_Tsk4_Emp		: std_logic;
signal sgn_Fifo_Tsk4_Full		: std_logic;

signal sgn_sBn					: Natural range 0 to gcst_sBucket_MaxCap;
signal sgn_p					: Natural range 0 to gcst_sBucket_Num;

-- stp3
signal sgn_CacheSel				: std_logic;
signal sgn_AccClr				: std_logic;

-- stp4
signal sgn_Bsy_Stp4				: std_logic;
signal sgn_Cache_Addr			: unsigned(gcst_WA_Cache-1 downto 0);
signal sgn_jk					: Natural;
signal sgn_AccInc				: std_logic;
signal sgn_mCL					: std_logic;
signal sgn_mBInc				: std_logic;
signal sgn_MemSel				: std_logic;

-- tri add
signal sgn_Acc					: Natural;
signal sgn_TriAdd_A1			: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_TriAdd_A2			: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_TriAdd_A3			: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_TriAdd_o				: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_TriAdd_o_Lst			: unsigned(gcst_WD_Cache_Idx-1 downto 0);

-- data latch and xor
signal sgn_CachDo				: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_mCollision			: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_xApdix				: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_xCollision			: unsigned(gcst_WD_Cache_Data-1 downto 0);
signal sgn_stp					: unsigned(gcst_WD_Cache_Idx-1 downto 0);
signal sgn_CmpRes				: std_logic;

-- input latch
signal sgn_ParamR_a				: Natural;
signal sgn_ParamR_b				: Natural;
signal sgn_LastRound			: std_logic;

-- mem output
signal sgn_MemIdxAddr			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemIdxAddr_Lst		: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemIdxDo_Lst			: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_MemIdxDoM			: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
signal sgn_MemIdxWr				: std_logic;
signal sgn_MemIdxWrM			: std_logic;

-- last info
signal sgn_TotNum				: Natural;
signal sgn_InfoLst_Wr			: std_logic;

-- task fifo (to stp2)
signal sgn_Fifo_Tsk2_Di			: unsigned(cst_FIFOTsk2_DW-1 downto 0);
signal sgn_Fifo_Tsk2_Do			: std_logic_vector(cst_FIFOTsk2_DW-1 downto 0);
signal sgn_Fifo_Tsk2_Rd			: std_logic;
signal sgn_Fifo_Tsk2_Wr			: std_logic;
signal sgn_Fifo_Tsk2_Emp		: std_logic;
signal sgn_Fifo_Tsk2_Full		: std_logic;

-- st and ed
signal sgn_St_Stp2_3			: std_logic;
signal sgn_Ed_Stp3_2			: std_logic;

signal sgn_mBn					: Natural;
signal sgn_q					: Natural;
signal sgn_AB_IdxArrSub			: unsigned(gcst_WA_Mem-1 downto 0);

signal sgn_i					: unsigned(gcst_WA_Mem-1 downto 0);

signal sgn_Stp2MemRd			: std_logic;
signal sgn_Stp2MemRdGuard		: Natural range 0 to gcst_mBucket_MaxCap+10;
signal sgn_Stp2MemRdBsy			: std_logic;
signal sgn_Stp2MemRdAck			: std_logic;

-- input data index gen
signal sgn_DataIdx_Cnt			: Natural;
signal sgn_DataIdxCntRst		: std_logic;

-- delay
constant cst_mCL_DL				: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1; -- mux -- 7
signal sgn_mCL_DL				: unsigned(0 downto 0);
--
constant cst_xApdix_DL			: Natural := 1; -- xor -- 1
signal sgn_xApdix_DL			: unsigned(gcst_WD_Cache_Idx-1 downto 0);
--
constant cst_mBInc_DL			: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1; -- mux / xor -- 8
signal sgn_mBInc_DL				: unsigned(0 downto 0);
--
constant cst_MemSel_DL1			: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1 + 1 +-- mux / xor / mux(sw/inc)
											gcst_AddrAuxCalc_RtlDL; -- 11
signal sgn_MemSel_DL1			: unsigned(0 downto 0);
--
constant cst_MemSel_DL2			: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1; -- mux / cmp -- 8
signal sgn_MemSel_DL2			: unsigned(0 downto 0);
--
constant cst_MemSel_DL3			: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1 + 1; -- mux / cmp / DL -- 9
signal sgn_MemSel_DL3			: unsigned(0 downto 0);
--
constant cst_MemIdxWr_DL		: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1; -- mux / cmp -- 8
signal sgn_MemIdxWr_DL				: unsigned(0 downto 0);
--
constant cst_MemIdxWrM_DL		: Natural := gcst_AddrAuxCalc_RtlDL + 
											1; -- mux -- 3
signal sgn_MemIdxWrM_DL			: unsigned(0 downto 0);
--
constant cst_MemIdxDo_DL		: Natural := gcst_LpmRam_RtlDL_Rd + 
											1; -- mux -- 3
signal sgn_MemIdxDo_DL			: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
--
constant cst_MemIdxDoM_DL		: Natural := gcst_AddrAuxCalc_RtlDL + 
											1; -- mux -- 3
signal sgn_MemIdxDoM_DL			: unsigned(gcst_WD_Cache_Apdix-1 downto 0);
--
constant cst_TriAddo_DL			: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 - 1; -- mux / add -- 6
signal sgn_TriAddo_DL			: unsigned(gcst_WD_Cache_Idx-1 downto 0);
--
constant cst_MemIdxAddr_DL		: Natural := gcst_LpmRam_RtlDL_Rd + 
											gcst_AddrAuxCalc_RtlDL + 
											gcst_LpmRam_RtlDL_Rd + 
											1 + 1 - -- mux / cmp 
											gcst_AddrAuxCalc_RtlDL +
											gcst_AddrAuxCalc_RtlDL; -- 8
signal sgn_MemIdxAddr_DL		: unsigned(gcst_WA_Mem-1 downto 0);
--
constant cst_CmpRes_DL			: Natural := 1; -- 6
signal sgn_CmpRes_DL			: unsigned(0 downto 0);
--
constant cst_Stp2MemRd_DL		: Natural := gcst_AddrAuxCalc_RtlDL; -- 2
signal sgn_Stp2MemRd_DL			: unsigned(0 downto 0);
--
constant cst_Stp2MemRdBsy_DL	: Natural := gcst_BucketDisp_RtlDL_pp + 
											 gcst_LpmRam_RtlDL_Rd + 1 - 1; -- 8
signal sgn_Stp2MemRdBsy_DL		: unsigned(0 downto 0);
--
constant cst_DataIdxCnt_DL		: Natural := gcst_BucketDisp_RtlDL_pp - 1; -- Acc 5
signal sgn_DataIdxCnt_DL		: Natural;
--============================ function declare ============================--

begin
-- input latch
process(clk,aclr) -- latch
begin
	if(aclr='1')then
		sgn_LastRound <= '0';
	elsif(rising_edge(clk))then
		if(sgn_St_Stp2_3='1')then
			sgn_LastRound <= LastRound;
		end if;
	end if;
end process;

process(clk) -- latch param_r
begin
	if(rising_edge(clk))then
		if(sgn_St_Stp2_3='1')then
			sgn_ParamR_a <= Param_r;
			sgn_ParamR_b <= Param_r + 1;
		end if;
	end if;
end process;

-- cache
-- data
inst01: altsyncram
generic map(
	numwords_a	=> cst_CacheD_Deepth,--:	natural;
	numwords_b	=> cst_CacheD_Deepth,--:	natural;
	widthad_a	=> cst_CacheD_ExpoDeepth,--:	natural; -- log2(x)
	widthad_b	=> cst_CacheD_ExpoDeepth,--:	natural; -- log2(x)
	width_a		=> gcst_WD_Cache_Data,--:	natural;
	width_b		=> gcst_WD_Cache_Data--:	natural
)
port map(
	address_a	=> std_logic_vector(sgn_Cache_Data_AddrWr),--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> std_logic_vector(sgn_Cache_Data_Di),--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Cache_Data_Wr,--:	in std_logic;
	
	address_b	=> std_logic_vector(sgn_Cache_Data_AddrRd),--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Cache_Data_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);
-- old idx
inst02: altsyncram
generic map(
	numwords_a	=> cst_Cache_Deepth,--:	natural;
	numwords_b	=> cst_Cache_Deepth,--:	natural;
	widthad_a	=> cst_Cache_ExpoDeepth,--:	natural; -- log2(x)
	widthad_b	=> cst_Cache_ExpoDeepth,--:	natural; -- log2(x)
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
-- data idx
inst03: altsyncram
generic map(
	numwords_a	=> cst_Cache_Deepth,--:	natural;
	numwords_b	=> cst_Cache_Deepth,--:	natural;
	widthad_a	=> cst_Cache_ExpoDeepth,--:	natural; -- log2(x)
	widthad_b	=> cst_Cache_ExpoDeepth,--:	natural; -- log2(x)
	width_a		=> cst_CacheD_ExpoDeepth,--:	natural;
	width_b		=> cst_CacheD_ExpoDeepth--:	natural
)
port map(
	address_a	=> std_logic_vector(sgn_Cache_DataIdx_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> std_logic_vector(sgn_Cache_DataIdx_Di),--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Cache_DataIdx_Wr,--:	in std_logic;
	
	address_b	=> std_logic_vector(sgn_Cache_DataIdx_Addr(cst_Cache_ExpoDeepth-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Cache_DataIdx_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- sBucket counter
inst04: Equihash_BucketDisp
port map(
	AB_Bucket	=> to_unsigned(gcst_sBucket_Sect,gcst_WA_Cache),--(const): in	unsigned(Width_Addr-1 downto 0); -- 0
	AB_Buff		=> to_unsigned(gcst_AB_Cache,gcst_WA_Cache),--: in	unsigned(Width_Addr-1 downto 0);

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

-- stp3
inst05: Equihash_GBP_CllsStp3
port map(
	sBucket_Init	=> sgn_sBucket_Init,--: out	std_logic;
	sBucket_Rdy		=> sgn_sBucket_Rdy,--: in	std_logic;
	
	sBucket_Get		=> sgn_sBucket_Get,--: out	std_logic;
	sBucket_GetIdx	=> sgn_sBucket_GetIdx,--: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	sBucket_Cnt		=> sgn_sBucket_Cnt,--: in	Natural range 0 to sBucket_MaxCap;
	
	Cache_Sel		=> sgn_CacheSel,--: out	std_logic; -- '1' current sm get control right
	Acc_Clr			=> sgn_AccClr,--: out	std_logic;
	
	LastRound		=> sgn_LastRound,--: in	std_logic;
	
	Buff_P_D		=> sgn_Fifo_Tsk4_Di,--: out	unsigned(gcst_WD_sBn+gcst_WD_ParamP-1 downto 0);
	Buff_P_Wr		=> sgn_Fifo_Tsk4_Wr,--: out	std_logic;
	Buff_P_Full		=> sgn_Fifo_Tsk4_Full,--: in	std_logic;
	Buff_P_Emp		=> sgn_Fifo_Tsk4_Emp,--: in	std_logic;
	
	ThEd_Req		=> sThEd_Req,--: out	std_logic;
	ThEd_Ack		=> sThEd_Ack,--: in	std_logic;
	InfoLst_Wr		=> sgn_InfoLst_Wr,--: out	std_logic;
	
	St				=> sgn_St_Stp2_3,--: in	std_logic;
	Ed				=> sgn_Ed_Stp3_2,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	Tsk_Bsy			=> sgn_Bsy_Stp4,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- task buffer between stp3 and stp4/5
inst06: scfifo
generic map(
	ram_block_type				=> "AUTO",
	add_ram_output_register		=> "ON",
	intended_device_family		=> Device_Family,--"Cyclone V";
	lpm_numwords				=> cst_FIFOTsk4_Deepth,
	lpm_showahead				=> "OFF",
	lpm_type					=> "scfifo",
	lpm_width					=> cst_FIFOTsk4_DW,
	lpm_widthu					=> Fnc_Int2Wd(cst_FIFOTsk4_Deepth-1),
	almost_full_value 			=> cst_FIFOTsk4_Deepth - cst_FIFOTsk4_rem,
	overflow_checking			=> "ON",
	underflow_checking			=> "ON",
	use_eab						=> "ON"
)
port map(
	data				=> std_logic_vector(sgn_Fifo_Tsk4_Di),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_Fifo_Tsk4_Wr,--: IN STD_LOGIC ;

	q					=> sgn_Fifo_Tsk4_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_Fifo_Tsk4_Rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_Fifo_Tsk4_Emp,--: OUT STD_LOGIC ;
	almost_full			=> sgn_Fifo_Tsk4_Full,--: out std_logic;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_p <= to_integer(unsigned(sgn_Fifo_Tsk4_Do(gcst_WD_sBn+gcst_WD_ParamP-1 downto gcst_WD_sBn)));
sgn_sBn <= to_integer(unsigned(sgn_Fifo_Tsk4_Do(gcst_WD_sBn-1 downto 0)));

-- stp4/5
inst07: Equihash_GBP_CllsStp4
port map(
	LastRound		=> sgn_LastRound,--(io): in	std_logic;
	
	Param_jk		=> sgn_jk,--: out	unsigned(gcst_WA_Cache-1 downto 0); -- hold 2clk every time

	Mem_Wr			=> sgn_MemIdxWr,--: out	std_logic; -- 1clk delay after Cache_Addr_j output
	mBucket_Inc		=> sgn_mBInc,--: out	std_logic;
	Mem_Sel			=> sgn_MemSel,--: out	std_logic;
	
	mC_Latch		=> sgn_mCL,--: out	std_logic;
	Acc_Inc			=> sgn_AccInc,--: out	std_logic;
	
	Buff_P_Rd		=> sgn_Fifo_Tsk4_Rd,--: out	std_logic;
	Buff_P_Emp		=> sgn_Fifo_Tsk4_Emp,--: in	std_logic;
	
	Ed				=> open,--: out	std_logic;
	Bsy				=> sgn_Bsy_Stp4,--: out	std_logic;
	
	Param_sBn		=> sgn_sBn,--: in	Natural range 0 to sBucket_MaxCap;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- cache address gen
inst08: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Cache--: Natural 32
)
port map(
	AB_M			=> to_unsigned(gcst_AB_Cache,gcst_WA_Cache),--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> to_unsigned(gcst_sBucket_Sect,gcst_WA_Cache),--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> to_unsigned(sgn_jk,gcst_WA_Cache),--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_p, gcst_WA_Cache),--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> sgn_Cache_Addr,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

-- connect cache port
-- data
sgn_Cache_Data_Di <= sgn_sBucketD(gcst_WD_Cache_Data-1 downto 0);
sgn_Cache_Data_AddrWr <= to_unsigned(sgn_DataIdxCnt_DL,cst_CacheD_ExpoDeepth);
sgn_Cache_Data_Wr <= sgn_sBucketWr;

sgn_Cache_Data_AddrRd <= unsigned(sgn_Cache_DataIdx_Do);

-- old index
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Cache_Apdix_Di <= sgn_sBucketD(gcst_WD_Mem-1 downto gcst_WD_Mem-gcst_WD_Cache_Apdix);
		if(sgn_CacheSel='0')then
			sgn_Cache_Apdix_Addr <= sgn_sBucketA; -- from sBucket
		else
			sgn_Cache_Apdix_Addr <= sgn_Cache_Addr; -- from stp4
		end if;
		
	end if;
end process;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Cache_Apdix_Wr <= '0';
	elsif(rising_edge(clk))then
		sgn_Cache_Apdix_Wr <= sgn_sBucketWr;
	end if;
end process;

-- data index
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Cache_DataIdx_Di <= to_unsigned(sgn_DataIdxCnt_DL,cst_CacheD_ExpoDeepth);
		if(sgn_CacheSel='0')then
			sgn_Cache_DataIdx_Addr <= sgn_sBucketA; -- from sBucket
		else
			sgn_Cache_DataIdx_Addr <= sgn_Cache_Addr; -- from stp4
		end if;
	end if;
end process;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Cache_DataIdx_Wr <= '0';
	elsif(rising_edge(clk))then
		sgn_Cache_DataIdx_Wr <= sgn_sBucketWr;
	end if;
end process;

-- new idx gen
-- acc
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_AccClr='1')then
			sgn_Acc <= 0;
		elsif(sgn_AccInc='1')then
			sgn_Acc <= sgn_Acc + sgn_sBn;
		end if;
	end if;
end process;
-- tri-add
sgn_TriAdd_A1 <= sgn_AB_IdxArrSub(gcst_WD_Cache_Idx-1 downto 0); -- 24bit
sgn_TriAdd_A2 <= to_unsigned(sgn_Acc, gcst_WD_Cache_Idx);
sgn_TriAdd_A3 <= to_unsigned(sgn_jk, gcst_WD_Cache_Idx);
process(clk)
begin
	if(rising_edge(clk))then
		sgn_TriAdd_o <= sgn_TriAdd_A1 + sgn_TriAdd_A2 + sgn_TriAdd_A3;
	end if;
end process;

-- data latch and xor
sgn_CachDo <= unsigned(sgn_Cache_Data_Do);
-- latch (data and new index)
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_mCL_DL(0) = '1')then
			sgn_mCollision <= sgn_CachDo;
			sgn_xApdix <= sgn_TriAddo_DL; -- DL6
		end if;
	end if;
end process;
-- xor data
process(clk)
begin
	if(rising_edge(clk))then
		sgn_xCollision <= sgn_mCollision xor sgn_CachDo;
	end if;
end process;
-- delay xApdix
--sgn_xApdix_DL
-- gen stp (sub)
process(clk)
begin
	if(rising_edge(clk))then
		sgn_stp <= sgn_TriAddo_DL - sgn_xApdix; -- DL6
	end if;
end process;
-- compare data
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_CachDo = sgn_mCollision)then
			sgn_CmpRes <= '1';
		else
			sgn_CmpRes <= '0';
		end if;
	end if;
end process;

-- mBucket output
mBucket_Di <= sgn_stp(gcst_WD_Cache_Stp-1 downto 0) & -- 255~248(8bit)
			unsigned(sgn_xApdix_DL(gcst_WD_Cache_Idx-1 downto 0)) & -- 247~224(24bit)
			to_unsigned(0, gcst_WD_Mem-gcst_WD_Cache_Data-gcst_WD_Cache_Apdix) & -- 223~200(24bit)
			sgn_xCollision; -- 199~0(200bit)
mBucket_Inc <= sgn_mBInc_DL(0) and (not sgn_CmpRes); -- DL8

-- mem output
-- channel sel delay
-- sgn_MemSel_DL1 -- DL11
-- sgn_MemSel_DL2 -- DL8
-- sgn_MemSel_DL3 -- DL9
-- Mem Addr gen (not last round)
inst09: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Mem--: Natural 32
)
port map(
	AB_M			=> to_unsigned(gcst_AB_MemIdx,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> to_unsigned(gcst_AB_MemIdx_Sect,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> to_unsigned(to_integer(sgn_TriAdd_o),gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_ParamR_a,gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0); -- r
	
	A_o				=> sgn_MemIdxAddr,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);
--sgn_MemIdxAddr_DL -- DL8
-- Mem Addr gen (last round)
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_AccClr='1')then
			sgn_TriAdd_o_Lst <= sgn_TriAdd_A1;
		elsif(sgn_CmpRes_DL(0) = '1' and sgn_MemSel_DL3(0)='1')then -- DL9 read for next
			sgn_TriAdd_o_Lst <= sgn_TriAdd_o_Lst + 1;
		end if;
	end if;
end process;

inst10: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Mem--: Natural 32
)
port map(
	AB_M			=> to_unsigned(gcst_AB_MemIdx,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> to_unsigned(gcst_AB_MemIdx_Sect,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> to_unsigned(to_integer(sgn_TriAdd_o_Lst),gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_ParamR_b,gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0); -- r+1
	
	A_o				=> sgn_MemIdxAddr_Lst,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_MemSel_DL1(0) = '0')then -- DL11
			Mem_Idx_Addr <= sgn_MemIdxAddr_DL; -- stp4 -- DL8
		else
			Mem_Idx_Addr <= sgn_MemIdxAddr_Lst; -- stp5
		end if;
	end if;
end process;

-- Mem Wr
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_MemIdxWrM <= '0';
	elsif(rising_edge(clk))then
		if(sgn_MemSel_DL2(0)='0')then -- DL8
			sgn_MemIdxWrM <= sgn_MemIdxWr_DL(0); -- stp4 DL8
		else-- stp5
			sgn_MemIdxWrM <= sgn_MemIdxWr_DL(0) and sgn_CmpRes; -- stp5 DL8
		end if;
	end if;
end process;

Mem_Idx_Wr <= sgn_MemIdxWrM_DL(0); -- DL3

--Mem Do
sgn_MemIdxDo_Lst <= sgn_Stp(gcst_WD_Cache_Stp-1 downto 0) & -- 31~24(8bit)
				unsigned(sgn_xApdix_DL(gcst_WD_Cache_Idx-1 downto 0)); -- 23~0(24bit)

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_MemSel_DL2(0) = '0')then -- DL8
			sgn_MemIdxDoM <= sgn_MemIdxDo_DL; -- stp4 -- DL3
		else
			sgn_MemIdxDoM <= sgn_MemIdxDo_Lst; -- stp5
		end if;
	end if;
end process;

Mem_Idx_Do <= sgn_MemIdxDoM_DL; -- DL3

-- last round info output
InfoLst_AB <= sgn_AB_IdxArrSub;

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_AccClr='1')then
			sgn_TotNum <= 0;
		elsif(sgn_CmpRes='1' and sgn_LastRound='1')then
			sgn_TotNum <= sgn_TotNum + 1;
		end if;
	end if;
end process;
InfoLst_Num <= sgn_TotNum;

process(clk,aclr)
begin
	if(aclr='1')then
		InfoLst_Wr <= '0';
	elsif(rising_edge(clk))then
		if(sgn_TotNum/=0)then
			InfoLst_Wr <= sgn_InfoLst_Wr;
		else
			InfoLst_Wr <= '0';
		end if;
	end if;
end process;

-- stp2 read data to sBucket
inst11: Equihash_GBP_CllsStp2
port map(
	mBn				=> sgn_mBn,--: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	FIFO_Rd			=> sgn_Fifo_Tsk2_Rd,--: out	std_logic;
	FIFO_Emp		=> sgn_Fifo_Tsk2_Emp,--: in	std_logic;
	
	Mem_Addr_i		=> sgn_i,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			=> sgn_Stp2MemRd,--: out	std_logic;
	Mem_RdBsy		=> sgn_Stp2MemRdBsy_DL(0),--: in	std_logic;
	
	AccRst			=> sgn_DataIdxCntRst,--: out	std_logic;
	
	Ed				=> Ed,--(io): out	std_logic;
	Bsy				=> Bsy,--(io): out	std_logic;
	
	nxt_St			=> sgn_St_Stp2_3,--: out	std_logic;
	nxt_Ed			=> sgn_Ed_Stp3_2,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- task buffer from outside to stp2
inst12: scfifo
generic map(
	ram_block_type				=> "AUTO",
	add_ram_output_register		=> "ON",
	intended_device_family		=> Device_Family,--"Cyclone V";
	lpm_numwords				=> cst_FIFOTsk2_Deepth,
	lpm_showahead				=> "OFF",
	lpm_type					=> "scfifo",
	lpm_width					=> cst_FIFOTsk2_DW,
	lpm_widthu					=> Fnc_Int2Wd(cst_FIFOTsk2_Deepth-1),
	almost_full_value 			=> cst_FIFOTsk2_Deepth - cst_FIFOTsk2_rem,
	overflow_checking			=> "ON",
	underflow_checking			=> "ON",
	use_eab						=> "ON"
)
port map(
	data				=> std_logic_vector(sgn_Fifo_Tsk2_Di),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_Fifo_Tsk2_Wr,--: IN STD_LOGIC ;

	q					=> sgn_Fifo_Tsk2_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_Fifo_Tsk2_Rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_Fifo_Tsk2_Emp,--: OUT STD_LOGIC ;
	almost_full			=> sgn_Fifo_Tsk2_Full,--: out std_logic;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

-- connect fifo port
sgn_Fifo_Tsk2_Wr <= FIFO_Tsk_Wr;-- (io)
sgn_Fifo_Tsk2_Di(gcst_WD_mBn-1 downto 0) <= to_unsigned(FIFO_Tsk_Di.mBn,gcst_WD_mBn);
sgn_Fifo_Tsk2_Di(gcst_WD_mBn+gcst_WD_ParamQ-1 downto gcst_WD_mBn) 
										<= to_unsigned(FIFO_Tsk_Di.Param_q,gcst_WD_ParamQ);
sgn_Fifo_Tsk2_Di(cst_FIFOTsk2_DW-1 downto gcst_WD_mBn+gcst_WD_ParamQ) 
										<= FIFO_Tsk_Di.AB_IdxArrSub;

FIFO_Tsk_Full <= sgn_Fifo_Tsk2_Full;-- (io)
FIFO_Tsk_Emp <= sgn_Fifo_Tsk2_Emp;-- (io)

sgn_mBn <= to_integer(unsigned(
				sgn_Fifo_Tsk2_Do(gcst_WD_mBn-1 downto 0)
				));
sgn_q <= to_integer(unsigned(
				sgn_Fifo_Tsk2_Do(gcst_WD_mBn+gcst_WD_ParamQ-1 downto gcst_WD_mBn)
				));
sgn_AB_IdxArrSub <= unsigned(
				sgn_Fifo_Tsk2_Do(cst_FIFOTsk2_DW-1 downto gcst_WD_mBn+gcst_WD_ParamQ)
				);

-- read data addr gen
inst13: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Mem--: Natural 32
)
port map(
	AB_M			=> Mem_D_AB,--(io): in	unsigned(Width_A-1 downto 0);
	AB_S			=> to_unsigned(gcst_mBucket_Sect,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> sgn_i,--: in	unsigned(Width_A-1 downto 0);
	Sect			=> to_unsigned(sgn_q,gcst_WA_Mem),--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> Mem_D_Addr,--(io): out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

Mem_D_Rd <= sgn_Stp2MemRd_DL(0);

-- read finish guard
sgn_Stp2MemRdAck <= sBucket_Inc;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Stp2MemRdGuard <= 0;
	elsif(rising_edge(clk))then
		if(sgn_Stp2MemRdAck = '1' and sgn_Stp2MemRd = '1')then
			-- do nothing
		elsif(sgn_Stp2MemRdAck = '0' and sgn_Stp2MemRd = '1')then
			sgn_Stp2MemRdGuard <= sgn_Stp2MemRdGuard + 1;
		elsif(sgn_Stp2MemRdAck = '1' and sgn_Stp2MemRd = '0')then
			sgn_Stp2MemRdGuard <= sgn_Stp2MemRdGuard - 1;
		else
			-- do nothing
		end if;
	end if;
end process;

sgn_Stp2MemRdBsy <= '1' when sgn_Stp2MemRdGuard>0 else '0';

-- input data index gen
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_DataIdx_Cnt <= 0;
	elsif(rising_edge(clk))then
		if(sgn_DataIdxCntRst='1')then-- reset
			sgn_DataIdx_Cnt <= 0;
		elsif(sBucket_Inc='1')then--increase
			sgn_DataIdx_Cnt <= sgn_DataIdx_Cnt + 1;
		end if;
	end if;
end process;

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_mCL_DL)
port map(di => Fnc_STD2U0(sgn_mCL), do => sgn_mCL_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => gcst_WD_Cache_Idx, Num_Pipe => cst_xApdix_DL)
port map(di => sgn_xApdix, do => sgn_xApdix_DL, clk => clk, aclr => '0');
-- 
instPP03: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_mBInc_DL)
port map(di => Fnc_STD2U0(sgn_mBInc), do => sgn_mBInc_DL, clk => clk, aclr => aclr);
-- 
instPP04: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemSel_DL1)
port map(di => Fnc_STD2U0(sgn_MemSel), do => sgn_MemSel_DL1, clk => clk, aclr => aclr);
-- 
instPP05: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemSel_DL2)
port map(di => Fnc_STD2U0(sgn_MemSel), do => sgn_MemSel_DL2, clk => clk, aclr => aclr);
-- 
instPP06: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemSel_DL3)
port map(di => Fnc_STD2U0(sgn_MemSel), do => sgn_MemSel_DL3, clk => clk, aclr => aclr);
-- 
instPP07: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemIdxWr_DL)
port map(di => Fnc_STD2U0(sgn_MemIdxWr), do => sgn_MemIdxWr_DL, clk => clk, aclr => aclr);
-- 
instPP08: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemIdxWrM_DL)
port map(di => Fnc_STD2U0(sgn_MemIdxWrM), do => sgn_MemIdxWrM_DL, clk => clk, aclr => aclr);
--
instPP09: Lg_SingalPipe
generic map(Width_D => gcst_WD_Cache_Apdix, Num_Pipe => cst_MemIdxDo_DL)
port map(di => unsigned(sgn_Cache_Apdix_Do), do => sgn_MemIdxDo_DL, clk => clk, aclr => '0');
--
instPP10: Lg_SingalPipe
generic map(Width_D => gcst_WD_Cache_Apdix, Num_Pipe => cst_MemIdxDoM_DL)
port map(di => sgn_MemIdxDoM, do => sgn_MemIdxDoM_DL, clk => clk, aclr => '0');
--
instPP11: Lg_SingalPipe
generic map(Width_D => gcst_WD_Cache_Idx, Num_Pipe => cst_TriAddo_DL)
port map(di => sgn_TriAdd_o, do => sgn_TriAddo_DL, clk => clk, aclr => '0');
--
instPP12: Lg_SingalPipe
generic map(Width_D => gcst_WA_Mem, Num_Pipe => cst_MemIdxAddr_DL)
port map(di => sgn_MemIdxAddr, do => sgn_MemIdxAddr_DL, clk => clk, aclr => '0');
--
instPP13: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_CmpRes_DL)
port map(di => Fnc_STD2U0(sgn_CmpRes), do => sgn_CmpRes_DL, clk => clk, aclr => aclr);
--
instPP14: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp2MemRd_DL)
port map(di => Fnc_STD2U0(sgn_Stp2MemRd), do => sgn_Stp2MemRd_DL, clk => clk, aclr => aclr);
--
instPP15: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp2MemRdBsy_DL)
port map(di => Fnc_STD2U0(sgn_Stp2MemRdBsy), do => sgn_Stp2MemRdBsy_DL, clk => clk, aclr => aclr);
--
instPP16: Lg_SingalPipe_Nat
generic map(Num_Pipe => cst_DataIdxCnt_DL)
port map(di => sgn_DataIdx_Cnt, do => sgn_DataIdxCnt_DL, clk => clk, aclr => aclr);


end rtl;

