----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    26/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UnCompress - Behavioral
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

entity Equihash_GBP_UnCompress is
generic(
	Device_Family		: string := "Cyclone V"
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
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Equihash_GBP_UnCompress;

architecture rtl of Equihash_GBP_UnCompress is
--============================ constant declare ============================--
constant cst_Num_Ch		: Natural := 5;

constant cst_MemRd_DL			: Natural := gcst_IdxCache_RtlDL_Rd + gcst_AddrAuxCalc_RtlDL;
constant cst_Stp3_mValL_DL		: Natural := gcst_IdxCache_RtlDL_Rd;
constant cst_Stp3_CmpL_DL		: Natural := gcst_IdxCache_RtlDL_Rd;
constant cst_Stp5_ResValid_DL	: Natural := gcst_IdxCache_RtlDL_Rd;

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_GBP_UncmpStp1
port (
	Cache_A_Wr			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Di			: out	unsigned(gcst_WD_idxCache-1 downto 0);
	Cache_Wr			: out	std_logic;
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	InfoLst_AB			: in	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			: in	Natural;
	InfoLst_Rd			: out	std_logic;
	InfoLst_Emp			: in	std_logic;
	
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	nxt_Ed				: in	std_logic;
	nxt_abort			: in	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_UncmpStp2
port (
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_AWrGen_Rst	: out	std_logic;
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Mem_Addr_r			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_RdBsy			: in	std_logic;
	Mem_Valid			: in	std_logic;
	
	isLast				: out	std_logic;
	
	Valid				: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	pQit				: out	std_logic;
	
	nxt_St				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_UncmpStp3
port (
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	CmpRes				: in	std_logic;
	CmpRes_Rst			: out	std_logic;
	CmpRes_L			: out	std_logic;
	
	mVal_L				: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	pQit				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_UncmpStp4
port (
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_A_Wr			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr			: out	std_logic;
	
	CmpRes				: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_UncmpStp5
port (
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	rValid				: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Equihash_GBP_UnCRam
generic(
	Device_Family	: string := Device_Family;
	Num_Ch			: Natural := cst_Num_Ch -- 5
);
port (
	Wr			: in	unsigned(Num_Ch-1 downto 0);
	A_Wr		: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Di			: in	typ_1D_Idx_D(Num_Ch-1 downto 0); -- index 4word
	A_Rd		: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Do			: out	unsigned(gcst_WD_idxCache-1 downto 0);
	
	SelCh		: in	unsigned(Num_Ch-1 downto 0);
	SelRam		: in	unsigned(Num_Ch-1 downto 0); -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;

component Equihash_GBP_UnCMemIntf
generic(
	Device_Family	: string := Device_Family
);
port (
	Mem_Di		: in	unsigned(gcst_WD_idxCache-1 downto 0);
	Mem_RdAck	: in	std_logic;
	
	Cache_Di	: out	unsigned(gcst_WD_idxCache-1 downto 0);
	Cache_A_Wr	: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr	: out	std_logic;
	Cache_A_Rst	: in	std_logic;
	
	isLast		: in	std_logic;
	
	Valid		: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Equihash_AddrAuxCalc
generic(
	Width_A		: Natural := gcst_WA_Mem
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
	di		: in	unsigned(Width_D-1 downto 0);
	do		: out	unsigned(Width_D-1 downto 0);
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Cache_Wr			: unsigned(cst_Num_Ch-1 downto 0);
signal sgn_Cache_A_Wr		: typ_1D_Idx_A(cst_Num_Ch-1 downto 0);
signal sgn_Cache_Di			: typ_1D_Idx_D(cst_Num_Ch-1 downto 0); -- index 4word
signal sgn_Cache_A_Rd		: typ_1D_Idx_A(cst_Num_Ch-1 downto 0);
signal sgn_Cache_Do			: unsigned(gcst_WD_idxCache-1 downto 0);

signal sgn_Cache_SelCh		: unsigned(cst_Num_Ch-1 downto 0);
signal sgn_Cache_SelRam		: unsigned(cst_Num_Ch-1 downto 0); -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output

signal sgn_St_Stp1_Stp2		: std_logic;
signal sgn_St_Stp2_Stp3		: std_logic;
signal sgn_St_Stp3_Stp4		: std_logic;
signal sgn_St_Stp4_Stp5		: std_logic;

signal sgn_Ed_Stp3_Stp1		: std_logic;
signal sgn_Ed_Stp5_Stp1		: std_logic;

signal sgn_Cache_AWrGen_Rst	: std_logic;

signal sgn_MemAddr_r		: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemAddr_i		: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemAddr			: unsigned(gcst_WA_Mem-1 downto 0);
signal sgn_MemRd			: std_logic;
signal sgn_MemRd_DL			: unsigned(0 downto 0);

signal sgn_MemRdCnt		: Natural range 0 to gcst_Size_idxCache;
signal sgn_MemRdBsy		: std_logic;

signal sgn_Stp2_Valid		: std_logic;
signal sgn_Stp2_Abort		: std_logic;
signal sgn_Stp2_isLast		: std_logic;

signal sgn_Stp3_mValL		: std_logic;
signal sgn_Stp3_mValL_DL	: unsigned(0 downto 0);
signal sgn_Stp3_CmpL		: std_logic;
signal sgn_Stp3_CmpL_DL		: unsigned(0 downto 0);
signal sgn_Stp3_CmpRst		: std_logic;
signal sgn_Stp3_CmpRes		: std_logic;
signal sgn_Stp3_Abort		: std_logic;

signal sgn_Stp3_mVal		: Natural;
signal sgn_Stp3_sVal		: Natural;

signal sgn_Stp4_CmpRes		: std_logic;
signal sgn_Stp4_mVal		: Natural;
signal sgn_Stp4_sVal		: Natural;
signal sgn_Stp4_CacheAWr	: unsigned(gcst_WA_idxCache-1 downto 0);
signal sgn_Stp4_CacheWr		: std_logic;

constant cst_Stp4_CacheAWr_DL	: Natural := gcst_IdxCache_RtlDL_Rd;
signal sgn_Stp4_CacheAWr_DL		: unsigned(gcst_WA_idxCache-1 downto 0);
constant cst_Stp4_CacheWr_DL	: Natural := gcst_IdxCache_RtlDL_Rd;
signal sgn_Stp4_CacheWr_DL		: unsigned(0 downto 0);
constant cst_MemRdBsy_DL		: Natural := 2;
signal sgn_MemRdBsy_DL			: unsigned(0 downto 0);

signal sgn_Stp5_ResVlid			: std_logic;
signal sgn_ResValid_DL			: unsigned(0 downto 0);
--============================ function declare ============================--

begin

-- uncompress step1~5
inst01: Equihash_GBP_UncmpStp1
port map(
	Cache_A_Wr			=> sgn_Cache_A_Wr(0),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Di			=> sgn_Cache_Di(0),--: out	unsigned(gcst_WD_idxCache-1 downto 0);
	Cache_Wr			=> sgn_Cache_Wr(0),--: out	std_logic;
	
	Cache_SelCh			=> sgn_Cache_SelCh(0),--: out	std_logic;
	Cache_SelRam		=> sgn_Cache_SelRam(0),--: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	InfoLst_AB			=> InfoLst_AB,--(io): in	unsigned(gcst_WA_Mem-1 downto 0);
	InfoLst_Num			=> InfoLst_Num,--(io): in	Natural;
	InfoLst_Rd			=> InfoLst_Rd,--(io): out	std_logic;
	InfoLst_Emp			=> InfoLst_Emp,--(io): in	std_logic;
	
	Bsy					=> Bsy,--(io): out	std_logic;
	
	nxt_St				=> sgn_St_Stp1_Stp2,--(to setp 2): out	std_logic;
	nxt_Ed				=> sgn_Ed_Stp5_Stp1,--(from step 5): in	std_logic;
	nxt_abort			=> sgn_Ed_Stp3_Stp1,--(from step 3): in	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);
sgn_Ed_Stp3_Stp1 <= sgn_Stp2_Abort or sgn_Stp3_Abort;
-- unused
sgn_Cache_A_Rd(0) <= to_unsigned(0,gcst_WA_idxCache);

inst02: Equihash_GBP_UncmpStp2
port map(
	Cache_A_Rd			=> sgn_Cache_A_Rd(1),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_AWrGen_Rst	=> sgn_Cache_AWrGen_Rst,--: out	std_logic;
	
	Cache_SelCh			=> sgn_Cache_SelCh(1),--: out	std_logic;
	Cache_SelRam		=> sgn_Cache_SelRam(1),--: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Mem_Addr_r			=> sgn_MemAddr_r,--: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				=> sgn_MemRd,--: out	std_logic;
	Mem_RdBsy			=> sgn_MemRdBsy_DL(0),--: in	std_logic;
	Mem_Valid			=> Mem_Valid,--(io): in	std_logic;
	
	isLast				=> sgn_Stp2_isLast,--: out	std_logic;
	
	Valid				=> sgn_Stp2_Valid,--: in	std_logic;
	
	St					=> sgn_St_Stp1_Stp2,--: in	std_logic;
	Ed					=> open,--: out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	pQit				=> sgn_Stp2_Abort,--: out	std_logic;
	
	nxt_St				=> sgn_St_Stp2_Stp3,--(to step 3): out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);
-- from memory
--sgn_Cache_Wr(1)
--sgn_Cache_A_Wr(1)
--sgn_Cache_Di(1)

inst03: Equihash_GBP_UncmpStp3
port map(
	Cache_A_Rd			=> sgn_Cache_A_Rd(2),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	
	Cache_SelCh			=> sgn_Cache_SelCh(2),--: out	std_logic;
	Cache_SelRam		=> sgn_Cache_SelRam(2),--: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	CmpRes				=> sgn_Stp3_CmpRes,--: in	std_logic;
	CmpRes_Rst			=> sgn_Stp3_CmpRst,--: out	std_logic;
	CmpRes_L			=> sgn_Stp3_CmpL,--: out	std_logic;
	
	mVal_L				=> sgn_Stp3_mValL,--: out	std_logic;
	
	St					=> sgn_St_Stp2_Stp3,--: in	std_logic;
	Ed					=> open,--: out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	nxt_St				=> sgn_St_Stp3_Stp4,--(to steo 4): out	std_logic;
	pQit				=> sgn_Stp3_Abort,--(to steo 1): out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);
-- unused
sgn_Cache_Wr(2) <= '0';
sgn_Cache_A_Wr(2) <= to_unsigned(0,gcst_WA_idxCache);
sgn_Cache_Di(2) <= to_unsigned(0,gcst_WD_idxCache);

inst04: Equihash_GBP_UncmpStp4
port map(
	Cache_SelCh			=> sgn_Cache_SelCh(3),--: out	std_logic;
	Cache_SelRam		=> sgn_Cache_SelRam(3),--: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			=> sgn_Cache_A_Rd(3),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_A_Wr			=> sgn_Stp4_CacheAWr,--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr			=> sgn_Stp4_CacheWr,--: out	std_logic;
	
	CmpRes				=> sgn_Stp4_CmpRes,--: in	std_logic;
	
	St					=> sgn_St_Stp3_Stp4,--: in	std_logic;
	Ed					=> open,--: out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	nxt_St				=> sgn_St_Stp4_Stp5,--(to step 5): out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);
-- from cache output
sgn_Cache_Di(3) <= sgn_Cache_Do;
sgn_Cache_A_Wr(3) <= sgn_Stp4_CacheAWr_DL; -- delay
sgn_Cache_Wr(3) <= sgn_Stp4_CacheWr_DL(0); -- delay

inst05: Equihash_GBP_UncmpStp5
port map(
	Cache_SelCh			=> sgn_Cache_SelCh(4),--: out	std_logic;
	Cache_SelRam		=> sgn_Cache_SelRam(4),--: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			=> sgn_Cache_A_Rd(4),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	rValid				=> sgn_Stp5_ResVlid,--: out	std_logic;
	
	St					=> sgn_St_Stp4_Stp5,--: in	std_logic;
	Ed					=> sgn_Ed_Stp5_Stp1,--: out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);
-- unused
sgn_Cache_Wr(4) <= '0';
sgn_Cache_A_Wr(4) <= to_unsigned(0,gcst_WA_idxCache);
sgn_Cache_Di(4) <= to_unsigned(0,gcst_WD_idxCache);

-- idx cache
inst06: Equihash_GBP_UnCRam
port map(
	Wr			=> sgn_Cache_Wr,--: in	unsigned(Num_Ch-1 downto 0);
	A_Wr		=> sgn_Cache_A_Wr,--: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Di			=> sgn_Cache_Di,--: in	typ_1D_Idx_D(Num_Ch-1 downto 0); -- index 4word
	A_Rd		=> sgn_Cache_A_Rd,--: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Do			=> sgn_Cache_Do,--: out	unsigned(gcst_WD_idxCache-1 downto 0);
	
	SelCh		=> sgn_Cache_SelCh,--: in	unsigned(Num_Ch-1 downto 0);
	SelRam		=> sgn_Cache_SelRam,--: in	unsigned(Num_Ch-1 downto 0); -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic := '0'
);

-- input from memory
inst07: Equihash_GBP_UnCMemIntf
port map(
	Mem_Di		=> Mem_Di,--(io): in	unsigned(gcst_WD_idxCache-1 downto 0);
	Mem_RdAck	=> Mem_RdAck,--(io): in	std_logic;
	
	Cache_Di	=> sgn_Cache_Di(1),--: out	unsigned(gcst_WD_idxCache-1 downto 0);
	Cache_A_Wr	=> sgn_Cache_A_Wr(1),--: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr	=> sgn_Cache_Wr(1),--: out	std_logic;
	Cache_A_Rst	=> sgn_Cache_AWrGen_Rst,--: in	std_logic;
	
	isLast		=> sgn_Stp2_isLast,--: in	std_logic;
	
	Valid		=> sgn_Stp2_Valid,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- step 2 
-- Mem Addr gen
inst08: Equihash_AddrAuxCalc
port map(
	AB_M			=> AB_MemIdx_Base,--to_unsigned(gcst_AB_MemIdx,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	AB_S			=> AB_MemIdx_Sect,--to_unsigned(gcst_AB_MemIdx_Sect,gcst_WA_Mem),--(const): in	unsigned(Width_A-1 downto 0);
	
	Idx				=> sgn_MemAddr_i,--: in	unsigned(Width_A-1 downto 0);
	Sect			=> sgn_MemAddr_r,--: in	unsigned(Width_A-1 downto 0);
	
	A_o				=> Mem_A,--(io): out	unsigned(Width_A-1 downto 0);
	
	clk				=> clk--: in	std_logic
);

t0100: if(gcst_WD_idxCache < gcst_WA_Mem)generate
	sgn_MemAddr_i(gcst_WA_Mem-1 downto gcst_WD_idxCache) <= to_unsigned(0, gcst_WA_Mem-gcst_WD_idxCache);
end generate t0100;
sgn_MemAddr_i(gcst_WD_idxCache-1 downto 0) <= sgn_Cache_Do; -- 32bit
Mem_Rd <= sgn_MemRd_DL(0);

-- read guard
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_MemRdCnt <= 0;
		sgn_MemRdBsy <= '0';
	elsif(rising_edge(clk))then
		if(sgn_Stp2_isLast='0')then
			if(sgn_MemRd='1' and sgn_Cache_Wr(1) = '0')then
				sgn_MemRdCnt <= sgn_MemRdCnt + 2;
			elsif(sgn_MemRd='0' and sgn_Cache_Wr(1) = '1')then
				sgn_MemRdCnt <= sgn_MemRdCnt - 1;
			elsif(sgn_MemRd='1' and sgn_Cache_Wr(1) = '1')then
				sgn_MemRdCnt <= sgn_MemRdCnt + 1;
			end if;
		else-- last round
			if(sgn_MemRd='1' and sgn_Cache_Wr(1) = '0')then
				sgn_MemRdCnt <= sgn_MemRdCnt + 1;
			elsif(sgn_MemRd='0' and sgn_Cache_Wr(1) = '1')then
				sgn_MemRdCnt <= sgn_MemRdCnt - 1;
			end if;
		end if;
		if(sgn_MemRdCnt=0)then
			sgn_MemRdBsy <= '0';
		else
			sgn_MemRdBsy <= '1';
		end if;
		
	end if;
end process;

-- step 3
-- latch
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp3_mValL_DL(0) = '1')then -- mVal latch
			sgn_Stp3_mVal <= to_integer(sgn_Cache_Do);
		end if;
	end if;
end process;

-- compare
sgn_Stp3_sVal <= to_integer(sgn_Cache_Do);

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Stp3_CmpRes <= '0';
	elsif(rising_edge(clk))then
		if(sgn_Stp3_CmpRst = '1')then -- reset result
			sgn_Stp3_CmpRes <= '0';
		else
			if(sgn_Stp3_CmpL_DL(0) = '1')then -- compare enable
				if(sgn_Stp3_sVal = sgn_Stp3_mVal)then -- equal
					sgn_Stp3_CmpRes <= '1';
				end if;
			end if;
		end if;
	end if;
end process;

-- step 4
-- compare
sgn_Stp4_sVal <= to_integer(sgn_Cache_Do);
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Stp4_mVal <= to_integer(sgn_Cache_Do);
	end if;
end process;

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Stp4_sVal < sgn_Stp4_mVal)then
			sgn_Stp4_CmpRes <= '1';
		else
			sgn_Stp4_CmpRes <= '0';
		end if;
	end if;
end process;

-- step 5
Res <= sgn_Cache_Do;
ResValid <= sgn_ResValid_DL(0);

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemRd_DL) -- 4+2=6
port map(di => Fnc_STD2U0(sgn_MemRd), do => sgn_MemRd_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp3_mValL_DL) -- 4
port map(di => Fnc_STD2U0(sgn_Stp3_mValL), do => sgn_Stp3_mValL_DL, clk => clk, aclr => aclr);
--
instPP03: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp3_CmpL_DL) -- 4
port map(di => Fnc_STD2U0(sgn_Stp3_CmpL), do => sgn_Stp3_CmpL_DL, clk => clk, aclr => aclr);
--
instPP04: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp5_ResValid_DL) -- 4
port map(di => Fnc_STD2U0(sgn_Stp5_ResVlid), do => sgn_ResValid_DL, clk => clk, aclr => aclr);
--
instPP05: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Stp4_CacheWr_DL) -- 4
port map(di => Fnc_STD2U0(sgn_Stp4_CacheWr), do => sgn_Stp4_CacheWr_DL, clk => clk, aclr => aclr);
--
instPP06: Lg_SingalPipe
generic map(Width_D => gcst_WA_idxCache, Num_Pipe => cst_Stp4_CacheAWr_DL) -- 4
port map(di => sgn_Stp4_CacheAWr, do => sgn_Stp4_CacheAWr_DL, clk => clk, aclr => '0');
--
instPP07: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_MemRdBsy_DL) -- 2
port map(di => Fnc_STD2U0(sgn_MemRdBsy), do => sgn_MemRdBsy_DL, clk => clk, aclr => '0');

end rtl;
