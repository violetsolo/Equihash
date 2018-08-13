----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    28/06/2018 
-- Design Name: 
-- Module Name:    Equihash_PoW_Wrapper - Behavioral
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
--use ieee.math_real.all; -- only for test

library work;
use work.LgGlobal_pkg.all;
use work.Equihash_pkg.all;

entity Equihash_PoW_Wrapper is
generic(
	Device_Family		: string := "Cyclone V";
	Num_sThread			: Positive := 1
);
port (
	Nounce				: in	typ_1D_Word(gcst_W_Nounce-1 downto 0); -- 32B
	-- Mem addr base and sect
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	-- read data from buffer (memory)
	Mem_D_A_Rd			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_D_Rd			: out	unsigned(Num_sThread-1 downto 0);
	Mem_D_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_D_RdAck			: in	unsigned(Num_sThread-1 downto 0);
	Mem_D_RdValid		: in	unsigned(Num_sThread-1 downto 0);
	-- write data into memory
	Mem_D_A_Wr			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_D_Do			: out	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_D_Wr			: out	unsigned(Num_sThread-1 downto 0);
	Mem_D_WrValid		: in	unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
	Mem_Idx_A_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Idx_Rd			: out	std_logic;
	Mem_Idx_Di			: in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_Idx_RdAck		: in	std_logic;
	Mem_Idx_RdValid		: in	std_logic;
	-- write index info into memory
	Mem_Idx_A_Wr		: out	typ_1D_MemApdix_A(Num_sThread-1 downto 0);
	Mem_Idx_Do			: out	typ_1D_MemApdix_D(Num_sThread-1 downto 0);
	Mem_Idx_Wr			: out	unsigned(Num_sThread-1 downto 0);
	Mem_Idx_WrValid		: in	unsigned(Num_sThread-1 downto 0);
	-- result
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	-- sThread control
	Thread_Msk			: in	unsigned(Num_sThread-1 downto 0); --'1'valid, '0' invalid
	-- start and end
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_PoW_Wrapper;

architecture rtl of Equihash_PoW_Wrapper is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_GBP_Wrapper
generic(
	Device_Family		: string := Device_Family;
	Num_sThread			: Positive := Num_sThread
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
	-- Bucket data input and counter increase, port for DAG
	Bucket_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Bucket_Inc			: in	unsigned(Num_sThread-1 downto 0);
	-- Mem addr base and sect
	AB_MemD_BaseA		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		: in	unsigned(gcst_WA_Mem-1 downto 0);
	-- read data from buffer (memory)
	Mem_p1_A			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_p1_Rd			: out	unsigned(Num_sThread-1 downto 0);
	Mem_p1_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_p1_RdAck		: in	unsigned(Num_sThread-1 downto 0);
	Mem_p1_Valid		: in	unsigned(Num_sThread-1 downto 0);
	-- write index info into memory
	Mem_p2_A			: out	typ_1D_MemApdix_A(Num_sThread-1 downto 0);
	Mem_p2_Do			: out	typ_1D_MemApdix_D(Num_sThread-1 downto 0);
	Mem_p2_Wr			: out	unsigned(Num_sThread-1 downto 0);
	Mem_p2_Valid		: in	unsigned(Num_sThread-1 downto 0);
	-- write data into memory
	Mem_p3_A			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_p3_Do			: out	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_p3_Wr			: out	unsigned(Num_sThread-1 downto 0);
	Mem_p3_Valid		: in	unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
	Mem_p4_A			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p4_Rd			: out	std_logic;
	Mem_p4_Di			: in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_p4_RdAck		: in	std_logic;
	Mem_p4_Valid		: in	std_logic;
	-- result
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	-- sThread control
	Thread_Msk			: in	unsigned(Num_sThread-1 downto 0); --'1'valid, '0' invalid
	-- GBP process strat
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Equihash_DBG_Wrapper
port (
	AB_MemD_Base		: in	unsigned(gcst_WA_Mem-1 downto 0);
	
	Nounce				: in	typ_1D_Word(gcst_W_Nounce-1 downto 0); -- 32B
	-- Bucket router config
	BucketRt_Config		: out	std_logic; -- high priority
	BucketRt_IncSet		: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	: out	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			: out	std_logic;
	Bucket_Rdy			: in	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		: out	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	
	Valid				: in	std_logic;
	
	Bucket_Di			: out	unsigned(gcst_WD_Mem-1 downto 0); -- 256bit
	Bucket_Inc			: out	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
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
	-- Bucket router config
signal sgn_BucketRt_Config		: std_logic; -- high priority
signal sgn_BucketRt_IncSet		: std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
signal sgn_BucketRt_GetSet		: std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
signal sgn_BucketRt_MemChSel	: std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
signal sgn_Bucket_Init			: std_logic;
signal sgn_Bucket_Rdy			: std_logic;
	-- Bucket param set
signal sgn_Bucket_AB_Buff		: unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
signal sgn_Bucket_ChunkSel		: Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	-- Bucket data input and counter increase
signal sgn_Bucket_Di			: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal sgn_Bucket_Inc			: unsigned(Num_sThread-1 downto 0);

type typ_state is (S_Idle, S_DBG, S_GBP);
signal state			: typ_state;

signal sgn_DBG_St			: std_logic;
signal sgn_DBG_Ed			: std_logic;
signal sgn_GBP_St			: std_logic;
signal sgn_GBP_Ed			: std_logic;

constant cst_DBG_Ed_DL			: Natural := gcst_BucketDisp_RtlDL_pp + 
											 gcst_BucketRt2x2_RtlDL + 
											 gcst_BucketMix_RtlDL + 
											 1;
signal sgn_DBG_Ed_DL			: unsigned(0 downto 0);
--============================ function declare ============================--

begin

inst01: Equihash_GBP_Wrapper
port map(
	-- Bucket router config
	BucketRt_Config		=> sgn_BucketRt_Config,--: in	std_logic; -- high priority
	BucketRt_IncSet		=> sgn_BucketRt_IncSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		=> sgn_BucketRt_GetSet,--: in	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	=> sgn_BucketRt_MemChSel,--: in	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			=> sgn_Bucket_Init,--: in	std_logic;
	Bucket_Rdy			=> sgn_Bucket_Rdy,--: out	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		=> sgn_Bucket_AB_Buff,--: in	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		=> sgn_Bucket_ChunkSel,--: in	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	-- Bucket data input and counter increase
	Bucket_Di			=> sgn_Bucket_Di,--: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Bucket_Inc			=> sgn_Bucket_Inc,--: in	unsigned(Num_sThread-1 downto 0);
	-- Mem addr base and sect
	AB_MemD_BaseA		=> AB_MemD_BaseA,--to_unsigned(gcst_AB_MemD_BaseA,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_BaseB		=> AB_MemD_BaseB,--to_unsigned(gcst_AB_MemD_BaseB,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemD_Sect		=> AB_MemD_Sect,--to_unsigned(gcst_AB_MemD_Sect,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Base		=> AB_MemIdx_Base,--to_unsigned(gcst_AB_MemIdx_Base,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	AB_MemIdx_Sect		=> AB_MemIdx_Sect,--to_unsigned(gcst_AB_MemIdx_Sect,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	-- read data from buffer (memory)
	Mem_p1_A			=> Mem_D_A_Rd,--(io): out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_p1_Rd			=> Mem_D_Rd,--(io): out	unsigned(Num_sThread-1 downto 0);
	Mem_p1_Di			=> Mem_D_Di,--(io): in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_p1_RdAck		=> Mem_D_RdAck,--(io): in	unsigned(Num_sThread-1 downto 0);
	Mem_p1_Valid		=> Mem_D_RdValid,--: in	unsigned(Num_sThread-1 downto 0);
	-- write index info into memory
	Mem_p2_A			=> Mem_Idx_A_Wr,--(io): out	typ_1D_MemApdix_A(Num_sThread-1 downto 0);
	Mem_p2_Do			=> Mem_Idx_Do,--(io): out	typ_1D_MemApdix_D(Num_sThread-1 downto 0);
	Mem_p2_Wr			=> Mem_Idx_Wr,--(io): out	unsigned(Num_sThread-1 downto 0);
	Mem_p2_Valid		=> Mem_Idx_WrValid,--: in	unsigned(Num_sThread-1 downto 0);
	-- write data into memory
	Mem_p3_A			=> Mem_D_A_Wr,--(io): out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_p3_Do			=> Mem_D_Do,--(io): out	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_p3_Wr			=> Mem_D_Wr,--(io): out	unsigned(Num_sThread-1 downto 0);
	Mem_p3_Valid		=> Mem_D_WrValid,--: in	unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
	Mem_p4_A			=> Mem_Idx_A_Rd,--(io): out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_p4_Rd			=> Mem_Idx_Rd,--(io): out	std_logic;
	Mem_p4_Di			=> Mem_Idx_Di,--(io): in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_p4_RdAck		=> Mem_Idx_RdAck,--(io): in	std_logic;
	Mem_p4_Valid		=> Mem_Idx_RdValid,--: in	std_logic;
	-- result
	ResValid			=> ResValid,--(io): out	std_logic;
	Res					=> Res,--(io): out	unsigned(gcst_WD_idxCache-1 downto 0);
	-- sThread control
	Thread_Msk			=> Thread_Msk,--: in	unsigned(Num_sThread-1 downto 0); --'1'valid, '0' invalid
	-- GBP process strat
	St					=> sgn_GBP_St,--: in	std_logic;
	Ed					=> sgn_GBP_Ed,--: out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

inst02: Equihash_DBG_Wrapper
port map(
	AB_MemD_Base		=> AB_MemD_BaseA,--to_unsigned(gcst_AB_MemD_BaseA,gcst_WA_Mem),--(const): in	unsigned(gcst_WA_Mem-1 downto 0);
	
	Nounce				=> Nounce,--(io): in	typ_1D_Word(gcst_W_Nounce-1 downto 0); -- 32B
	-- Bucket router config
	BucketRt_Config		=> sgn_BucketRt_Config,--: out	std_logic; -- high priority
	BucketRt_IncSet		=> sgn_BucketRt_IncSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		=> sgn_BucketRt_GetSet,--: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	=> sgn_BucketRt_MemChSel,--: out	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			=> sgn_Bucket_Init,--: out	std_logic;
	Bucket_Rdy			=> sgn_Bucket_Rdy,--: in	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		=> sgn_Bucket_AB_Buff,--: out	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		=> sgn_Bucket_ChunkSel,--: out	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	
	Valid				=> '1',--: in	std_logic;
	
	Bucket_Di			=> sgn_Bucket_Di(0),--open, -- (only for test)--(always ch0): out	unsigned(gcst_WD_Mem-1 downto 0); -- 256bit
	Bucket_Inc			=> sgn_Bucket_Inc(0),--(always ch0): out	std_logic;
	
	St					=> sgn_DBG_St,--: in	std_logic;
	Ed					=> sgn_DBG_Ed,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

---- only for test
--process(clk)
--variable var_RandomVal	: Real;
--variable var_RandomInt	: integer ;
--variable var_Seed1		: Positive := 756;
--variable var_Seed2		: Positive := 4731;
--begin
--	if(rising_edge(clk))then
--		for i in 0 to gcst_N_Chunk-1 loop
--			-- low 12bit
--			uniform(var_Seed1, var_Seed2, var_RandomVal) ;
--			var_RandomInt := integer(trunc(var_RandomVal*63.0)) ;
--			sgn_Bucket_Di(0)((i+1)*gcst_W_Chunk-1-8 downto i*gcst_W_Chunk) <= to_unsigned(var_RandomInt, 12); --gcst_W_Chunk);
--			-- high 8bit
--			uniform(var_Seed1, var_Seed2, var_RandomVal) ;
--			var_RandomInt := integer(trunc(var_RandomVal*31.0)) ;
--			sgn_Bucket_Di(0)((i+1)*gcst_W_Chunk-1 downto i*gcst_W_Chunk+12) <= to_unsigned(var_RandomInt, 8); -- gcst_W_Chunk);
--		end loop;
--		-- padding
--		sgn_Bucket_Di(0)(224-1 downto 200) <= (others => '0');
--		-- Idx
--		uniform(var_Seed1, var_Seed2, var_RandomVal) ;
--		var_RandomInt := integer(trunc(var_RandomVal*3145728.0)) ;
--		sgn_Bucket_Di(0)(224+gcst_WD_Cache_Idx-1 downto 224) <= to_unsigned(var_RandomInt, gcst_WD_Cache_Idx);
--		-- stp
--		sgn_Bucket_Di(0)(gcst_WD_Mem-1 downto 224+gcst_WD_Cache_Idx) <= to_unsigned(0, gcst_WD_Cache_Stp);
--	end if;
--end process;

t0100: if(Num_sThread > 1)generate
	sgn_Bucket_Inc(Num_sThread-1 downto 1) <= (others => '0');
end generate t0100;

process(clk,aclr)
begin
	if(aclr='1')then
		state <= S_Idle;
		sgn_GBP_St <= '0';
		sgn_DBG_St <= '0';
		Ed <= '0';
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					sgn_DBG_St <= '1';
					state <= S_DBG;
				end if;
			
			when S_DBG =>
				sgn_DBG_St <= '0';
				if(sgn_DBG_Ed_DL(0)='1')then
					sgn_GBP_St <= '1';
					state <= S_GBP;
				end if;
			
			when S_GBP =>
				sgn_GBP_St <= '0';
				if(sgn_GBP_Ed = '1')then
					Ed <= '1';
					state <= S_Idle;
				end if;
			
			when others => state <= S_Idle;
		end case;
	end if;
end process;

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_DBG_Ed_DL)
port map(di => Fnc_STD2U0(sgn_DBG_Ed), do => sgn_DBG_Ed_DL, clk => clk, aclr => aclr);

end rtl;
