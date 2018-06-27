----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    27/06/2018 
-- Design Name: 
-- Module Name:    Equihash_DBG_Wrapper - Behavioral
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
use work.Blake2b_pkg.all;

entity Equihash_DBG_Wrapper is
port (
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
end Equihash_DBG_Wrapper;

architecture rtl of Equihash_DBG_Wrapper is
--============================ constant declare ============================--
constant cst_Param_Personal		: String := "ZcashPoW";
constant cst_Param_n		: unsigned(4*gcst_WW-1 downto 0) := to_unsigned(gcst_Equihash_n, 4*gcst_WW);
constant cst_Param_k		: unsigned(4*gcst_WW-1 downto 0) := to_unsigned(gcst_Equihash_k, 4*gcst_WW);
constant cst_Patram_Count	: unsigned(2*gcst_Blake_SubWW*gcst_WW-1 downto 0) := to_unsigned(gcst_W_Nounce+gcst_W_Idx, 2*gcst_Blake_SubWW*gcst_WW);

constant cst_ResNum_bit			: Natural := gcst_W_Chunk * gcst_N_Chunk; -- 200
constant cst_ResNum_Byt			: Natural := cst_ResNum_bit/gcst_WW; -- 25
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Equihash_DBG_Ctrl
generic(
	Num_Idx				: Natural := 2**(gcst_W_Chunk) -- 2^20
);
port (
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
	
	Idx					: out	Natural;
	
	Trg					: out	std_logic;
	Sel					: out	std_logic;
	Valid				: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end component;

component Blake2b_Lite
port (
	Param		: in	typ_Blake_Param; -- must be hold until calculate finish
	msg_i		: in	typ_1D_Word(gcst_Blake_WW-1 downto 0); -- 128-byte (16 double word) chunk of message to compress
	isLast		: in	std_logic := '1'; -- '0' not last data '1' last data Indicates if this is the final round of compression
	Count		: in	unsigned(2*gcst_Blake_SubWW*gcst_WW-1 downto 0); -- 16B=128b Count of bytes that have been fed into the Compression(include current bytes)
	
	hash_o		: out	typ_1D_Word(gcst_Blake_WW/2-1 downto 0); -- 64B
	
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
signal sgn_Blake2b_Param	: typ_Blake_Param;
signal sgn_Blake2b_msg		: typ_1D_Word(gcst_Blake_WW-1 downto 0);
signal sgn_Blake2b_Res		: typ_1D_Word(gcst_Blake_WW/2-1 downto 0);

signal sgn_idx_fmt		: unsigned(gcst_W_Idx*gcst_WW-1 downto 0);
signal sgn_idx			: Natural;

signal sgn_Trg			: std_logic;
signal sgn_Sel			: std_logic;

constant cst_Trg_DL		: Natural := gcst_BlakeLite_RtlDL;
signal sgn_Trg_DL		: unsigned(0 downto 0);
constant cst_Sel_DL		: Natural := gcst_BlakeLite_RtlDL;
signal sgn_Sel_DL		: unsigned(0 downto 0);
constant cst_Idx_DL		: Natural := gcst_BlakeLite_RtlDL;
signal sgn_Idx_DL		: unsigned(gcst_W_Idx*gcst_WW-1 downto 0);
--============================ function declare ============================--

begin

inst01: Blake2b_Lite
port map(
	Param		=> sgn_Blake2b_Param,--: in	typ_Blake_Param; -- must be hold until calculate finish
	msg_i		=> sgn_Blake2b_msg,--: in	typ_1D_Word(gcst_Blake_WW-1 downto 0); -- 128-byte (16 double word) chunk of message to compress
	isLast		=> '1',--: in	std_logic := '1'; -- '0' not last data '1' last data Indicates if this is the final round of compression
	Count		=> cst_Patram_Count,--: in	unsigned(2*gcst_Blake_SubWW*gcst_WW-1 downto 0); -- 16B=128b Count of bytes that have been fed into the Compression(include current bytes)
	
	hash_o		=> sgn_Blake2b_Res,--: out	typ_1D_Word(gcst_Blake_WW/2-1 downto 0); -- 64B
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic := '0'
);
-- parameter set
sgn_Blake2b_Param.Digest_Len 	<= to_unsigned(25, 1*gcst_WW);
sgn_Blake2b_Param.Key_Len 		<= to_unsigned(0, 1*gcst_WW);
sgn_Blake2b_Param.Fanout 		<= to_unsigned(1, 1*gcst_WW);
sgn_Blake2b_Param.Deepth 		<= to_unsigned(1, 1*gcst_WW);
sgn_Blake2b_Param.Leaf_Len 		<= to_unsigned(0, 4*gcst_WW);
sgn_Blake2b_Param.Node_Offset 	<= to_unsigned(0, 4*gcst_WW);
sgn_Blake2b_Param.Xof_Len 		<= to_unsigned(0, 4*gcst_WW);
sgn_Blake2b_Param.Node_Deepth 	<= to_unsigned(0, 1*gcst_WW);
sgn_Blake2b_Param.Inner_Len 	<= to_unsigned(0, 1*gcst_WW);
sgn_Blake2b_Param.Rvs 			<= to_unsigned(0, 14*gcst_WW);
sgn_Blake2b_Param.Salt 			<= to_unsigned(0, 16*gcst_WW);

i0100: for i in 0 to 8-1 generate
--	sgn_Blake2b_Param.Personalization(i) <= to_unsigned(character'pos(cst_Param_Personal(i)), gcst_WW);
end generate i0100;
i0200: for i in 0 to 4-1 generate
	sgn_Blake2b_Param.Personalization((i+8+1)*gcst_WW-1 downto (i+8)*gcst_WW) <= cst_Param_n((i+1)*gcst_WW-1 downto i*gcst_WW);--n
end generate i0200;
i0300: for i in 0 to 4-1 generate
	sgn_Blake2b_Param.Personalization((i+1+12)*gcst_WW-1 downto (i+12)*gcst_WW) <= cst_Param_k((i+1)*gcst_WW-1 downto i*gcst_WW);--k
end generate i0300;
-- message generate
i0400: for i in 0 to gcst_W_Nounce-1 generate
	sgn_Blake2b_msg(i) <= Nounce(i);
end generate i0400;

sgn_idx_fmt <= to_unsigned(sgn_idx, gcst_W_Idx*gcst_WW);
i0500: for i in 0 to gcst_W_Idx-1 generate
	sgn_Blake2b_msg(i+gcst_W_Nounce) <= sgn_idx_fmt((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i0500;

i0600: for i in gcst_W_Nounce+gcst_W_Idx to gcst_Blake_WW-1 generate
	sgn_Blake2b_msg(i) <= to_unsigned(0,gcst_WW);
end generate i0600;

inst02: Equihash_DBG_Ctrl
port map(
	-- Bucket router config
	BucketRt_Config		=> BucketRt_Config,--(io): out	std_logic; -- high priority
	BucketRt_IncSet		=> BucketRt_IncSet,--(io): out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		=> BucketRt_GetSet,--(io): out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	=> BucketRt_MemChSel,--(io): out	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			=> Bucket_Init,--(io): out	std_logic;
	Bucket_Rdy			=> Bucket_Rdy,--(io): in	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		=> Bucket_AB_Buff,--(io): out	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		=> Bucket_ChunkSel,--(io): out	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	
	Idx					=> sgn_idx,--: out	Natural;
	
	Trg					=> sgn_Trg,--: out	std_logic;
	Sel					=> sgn_Sel,--: out	std_logic;
	Valid				=> Valid,--(io): in	std_logic;
	
	St					=> St,--(io): in	std_logic;
	Ed					=> Ed,--(io): out	std_logic;
	Bsy					=> open,--: out	std_logic;
	
	clk					=> clk,--: in	std_logic;
	aclr				=> aclr--: in	std_logic
);

-- output sel
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Sel_DL(0)='0')then-- first half result
			for i in 0 to cst_ResNum_Byt-1 loop
				Bucket_Di((i+1)*gcst_WW-1 downto i*gcst_WW) <= sgn_Blake2b_Res(i);
			end loop;
			Bucket_Di(gcst_WD_Mem-gcst_WD_Mem_Apdix-1 downto cst_ResNum_bit) <= (others => '0');
			Bucket_Di(gcst_WD_Mem-1 downto gcst_WD_Mem-gcst_WD_Mem_Apdix) <= to_unsigned(to_integer(sgn_Idx_DL srl 1),gcst_WD_Mem_Apdix); -- *2
		else -- first half result
			for i in 0 to cst_ResNum_Byt-1 loop
				Bucket_Di((i+1)*gcst_WW-1 downto i*gcst_WW) <= sgn_Blake2b_Res(i+cst_ResNum_Byt);
			end loop;
			Bucket_Di(gcst_WD_Mem-gcst_WD_Mem_Apdix-1 downto cst_ResNum_bit) <= (others => '0');
			Bucket_Di(gcst_WD_Mem-1 downto gcst_WD_Mem-gcst_WD_Mem_Apdix) <= to_unsigned(to_integer((sgn_Idx_DL srl 1)+1),gcst_WD_Mem_Apdix); -- *2+1
		end if;
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		Bucket_Inc <= '0';
	elsif(rising_edge(clk))then
		Bucket_Inc <= sgn_Trg_DL(0);
	end if;
end process;

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Trg_DL)
port map(di => Fnc_STD2U0(sgn_Trg), do => sgn_Trg_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_Sel_DL)
port map(di => Fnc_STD2U0(sgn_Sel), do => sgn_Sel_DL, clk => clk, aclr => aclr);
--
instPP03: Lg_SingalPipe
generic map(Width_D => gcst_W_Idx*gcst_WW, Num_Pipe => cst_Idx_DL)
port map(di => sgn_idx_fmt, do => sgn_Idx_DL, clk => clk, aclr => '0');
--


end rtl;
