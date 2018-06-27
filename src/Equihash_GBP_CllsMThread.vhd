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
	mBucket_Width		: Natural := 12;
	mBucket_Offset		: Natural := 0;
	mBucket_Num			: Natural := 2**12;
	mBucket_MaxCap		: Natural := 3*2**9;--2**11; -- 3*2**9
	Num_sThread			: Natural := 4;
	mBucket_CntSumDL	: Natural := 3
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
	
	LastRound					: out	std_logic;
	IdxMngRst					: out	std_logic;
	
	sBucket_ChunkSel			: out	Natural range 0 to gcst_N_Chunk-1;

	Mem_Addr					: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd						: out	std_logic;
	Mem_RdAck					: in	std_logic;
	
	Param_r						: out	Natural range 0 to gcst_Round := 0;
	
	sThread_Sel					: out Natural range 0 to Num_sThread-1;
	sThread_Ed					: in	unsigned(Num_sThread-1 downto 0);
	sThread_St					: out	std_logic;
	
	St							: in	std_logic;
	Ed							: out	std_logic;
	
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
	AB_Buff_A		: unsigned(gcst_WA_Mem-1 downto 0) := gcst_AB_MemA;
	AB_Buff_B		: unsigned(gcst_WA_Mem-1 downto 0) := gcst_AB_MemB
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

component Equihash_GBP_CllsStp2
generic(
	mBucket_Width		: Natural := mBucket_Width;
	mBucket_Offset		: Natural := mBucket_Offset;
	mBucket_Num			: Natural := mBucket_Num;
	mBucket_MaxCap		: Natural := mBucket_MaxCap; -- 3*2**9
	mBucket_CntSumDL	: Natural := mBucket_CntSumDL
);
port (
	mBucket_Get		: out	std_logic;
	mBucket_Cnt		: in	Natural range 0 to mBucket_MaxCap;
	
	Mem_Addr_i		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			: out std_logic;
	Mem_RdBsy		: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Equihash_GBP_CllsSDisp
generic(
	mBucket_Num		: Natural := mBucket_Num;
	Num_sThread		: Natural := Num_sThread
);
port (
	Param_q			: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sThread_Sel		: out Natural range 0 to Num_sThread-1;
	sThread_Ed		: in	unsigned(Num_sThread-1 downto 0);
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
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
-- st and end chain
signal sgn_St_Stp1_sThD			: std_logic;
signal sgn_St_sThD_Stp2			: std_logic;

signal sgn_Ed_Stp2_sThD			: std_logic;
signal sgn_Ed_sThD_Stp1			: std_logic;

-- param
-- from stp1
signal sgn_r					: Natural range 0 to gcst_Round;
-- from stp2
signal sgn_AB_Buff				: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_q					: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_i					: unsigned(gcst_WA_Mem-1 downto 0);

-- stp2
signal sgn_Stp2MemRdBsy			: std_logic;
signal sgn_Stp2MemRdAck			: std_logic;
signal sgn_Stp2MemRdGuard		: Natural range 0 to mBucket_MaxCap+10 := 0;
signal sgn_Stp2MemRd			: std_logic;

-- delay
constant cst_Stp2MemRd_DL		: Natural := gcst_AddrAuxCalc_RtlDL; -- 2
signal sgn_Stp2MemRd_DL			: unsigned(0 downto 0);
--
constant cst_Stp2MemRdBsy_DL	: Natural := gcst_BucketDisp_RtlDL_pp + 
											 gcst_LpmRam_RtlDL_Wr + 1; -- 8
signal sgn_Stp2MemRdBsy_DL		: unsigned(0 downto 0);

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
	
	IdxMngRst			=> IdxMngRst,--: out	std_logic;
	LastRound			=> LastRound,--: out	std_logic;
	
	Mem_AB_Buff_Rd		=> sgn_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_AB_Buff_Wr		=> mBucket_AB_Buff,--(IO): out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	=> sBucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	St					=> St,--(IO): in	std_logic;
	Ed					=> Ed,--(IO): out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	Param_r				=> Param_r,--: out	Natural range 0 to gcst_Round-1 := 0; -- hold during process
	nxt_St				=> sgn_St_Stp1_sThD,--: out	std_logic;
	nxt_Ed				=> sgn_Ed_sThD_Stp1,--: in	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

inst02: Equihash_GBP_CllsStp2
port map(
	mBucket_Get		=> mBucket_Get,--(IO): out	std_logic;
	mBucket_Cnt		=> mBucket_Cnt,--(IO): in	Natural range 0 to mBucket_MaxCap;
	
	Mem_Addr_i		=> sgn_i,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd			=> sgn_Stp2MemRd,--: out std_logic;
	Mem_RdBsy		=> sgn_Stp2MemRdBsy_DL(0),--: in	std_logic;
	
	St				=> sgn_St_sThD_Stp2,--: in	std_logic;
	Ed				=> sgn_Ed_Stp2_sThD,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	nxt_St			=> sThread_St,--: out	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst03: Equihash_GBP_CllsSDisp
port map(
	Param_q			=> sgn_q,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sThread_Sel		=> sThread_Sel,--: out Natural range 0 to Num_sThread-1;
	sThread_Ed		=> sThread_Ed,--: in	unsigned(Num_sThread-1 downto 0);
	
	St				=> sgn_St_Stp1_sThD,--: in	std_logic;
	Ed				=> sgn_Ed_sThD_Stp1,--: out	std_logic;
	Bsy				=> open,--: out	std_logic;
	
	nxt_St			=> sgn_St_sThD_Stp2,--: out	std_logic;
	nxt_Ed			=> sgn_Ed_Stp2_sThD,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

-- step 2 part
mBucket_GetIdx <= sgn_q(gcst_W_Chunk-1 downto 0);

-- read data from mem signals gen
inst09: Equihash_AddrAuxCalc
generic map(
	Width_A		=> gcst_WA_Mem--: Natural 32
)
port map(
	AB_M			=> sgn_AB_Buff,--: in	unsigned(Width_A-1 downto 0);
	AB_S			=> gcst_mBucket_Sect,--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> sgn_i,--: in	unsigned(Width_A-1 downto 0);
	Sect			=> sgn_q,--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> Mem_Addr,--: out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

Mem_Rd <= sgn_Stp2MemRd_DL(0);

-- read process guard
sgn_Stp2MemRdAck <= Mem_RdAck;

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

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp2MemRd_DL)
port map(di => Fnc_STD2U0(sgn_Stp2MemRd), do => sgn_Stp2MemRd_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp2MemRdBsy_DL)
port map(di => Fnc_STD2U0(sgn_Stp2MemRdBsy), do => sgn_Stp2MemRdBsy_DL, clk => clk, aclr => aclr);

end rtl;

