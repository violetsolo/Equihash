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
	Num_sThread			: Natural := 4
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
end Equihash_GBP_CllsMThread;

architecture rtl of Equihash_GBP_CllsMThread is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_GBP_CllsStp1
port (
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucketRt_Config	: out	std_logic;
	mBucketRt_IncSet	: out	std_logic;
	mBucketRt_GetSet	: out	std_logic;
	
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

component Equihash_GBP_CllsIdxMng
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
-- param
-- from stp2
signal sgn_IdxMngRst			: std_logic;

signal sgn_sThSt		: unsigned(Num_sThread-1 downto 0);
signal sgn_sThSt1		: unsigned(Num_sThread-1 downto 0);
signal sgn_NxtEd		: std_logic;
signal sgn_NxtSt		: std_logic;

signal sgn_MemIdx_Sub	: Natural;
-- delay

--============================ function declare ============================--

begin

inst01: Equihash_GBP_CllsStp1
port map(
	AB_MemD_BaseA		=> AB_MemD_BaseA,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		=> AB_MemD_BaseB,--: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucketRt_Config	=> mBucketRt_Config,--(IO): out	std_logic;
	mBucketRt_IncSet	=> mBucketRt_IncSet,--(IO): out	std_logic;
	mBucketRt_GetSet	=> mBucketRt_GetSet,--(IO): out	std_logic;
	
	mBucket_Init		=> mBucket_Init,--(IO): out	std_logic;
	mBucket_Rdy			=> mBucket_Rdy,--(IO): in	std_logic;
	mBucket_ChunkSel	=> mBucket_ChunkSel,--(IO): out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	IdxMngRst			=> sgn_IdxMngRst,--: out	std_logic;
	LastRound			=> LastRound,--(IO): out	std_logic;
	
	Mem_AB_Buff_Rd		=> Mem_AB_Buff_Rd,--(IO): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_AB_Buff_Wr		=> mBucket_AB_Buff,--(IO): out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sBucket_ChunkSel	=> sBucket_ChunkSel,--(IO): out	Natural range 0 to gcst_N_Chunk-1 := 0;
	
	St					=> St,--(IO): in	std_logic;
	Ed					=> Ed,--(IO): out	std_logic;
	Bsy					=> open,--(IO): out	std_logic;
	
	Param_r				=> Param_r,--(IO): out	Natural range 0 to gcst_Round-1 := 0; -- hold during process
	nxt_St				=> sgn_NxtSt,--: out	std_logic;
	nxt_Ed				=> sgn_NxtEd,--: in	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

nxt_St <= sgn_NxtSt;

-- sthread status manager
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_sThSt <= (others => '0');
		sgn_NxtEd <= '0';
	elsif(rising_edge(clk))then
		if(sgn_NxtSt='1')then
			sgn_sThSt <= (others => '1'); -- set all thread
		else
			for i in 0 to Num_sThread-1 loop
				if(nxt_Ed(i)='1')then
					sgn_sThSt(i) <= '0'; -- clear one thread
				end if;
			end loop;
		end if;
		
		sgn_sThSt1 <= sgn_sThSt; -- delay
		if(to_integer(sgn_sThSt1)/=0 and to_integer(sgn_sThSt)=0)then -- falling edge
			sgn_NxtEd <= '1';
		else
			sgn_NxtEd <= '0';
		end if;
		
	end if;
end process;

-- mem idx manager
inst02: Equihash_GBP_CllsIdxMng
port map(
	ReqNum	=> MemIdx_Num,--: in	typ_1D_Nat(Num_Ch-1 downto 0);
	Req		=> MemIdx_Req,--: in	unsigned(Num_Ch-1 downto 0);
	
	AckVal	=> sgn_MemIdx_Sub,--: out	Natural;
	Ack		=> MemIdx_Ack,--: out	unsigned(Num_Ch-1 downto 0);
	
	TotNum	=> open,--: out	Natural;
	Rst		=> sgn_IdxMngRst,--: in	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

MemIdx_Sub <= to_unsigned(sgn_MemIdx_Sub, gcst_WA_Mem);

-- delay

end rtl;

