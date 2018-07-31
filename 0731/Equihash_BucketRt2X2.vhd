----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/06/2018 
-- Design Name: 
-- Module Name:    Equihash_BucketRt2X2 - Behavioral
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

entity Equihash_BucketRt2X2 is
generic(
	Max_Counter		: Natural := 2**11 -- 3*2**9
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
end Equihash_BucketRt2X2;

architecture rtl of Equihash_BucketRt2X2 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_Inc			: std_logic;
signal sgn_Get			: std_logic;
--============================ function declare ============================--

begin
-- channel mix
process(Clk)
begin
	if(rising_edge(clk))then
		if(sgn_Inc='0')then
			ChAo_AB_Buff <= ChAi_AB_Buff;
			ChBo_AB_Buff <= ChBi_AB_Buff;
			ChAo_D_i <= ChAi_D_i;
			ChBo_D_i <= ChBi_D_i;
			ChAo_ChunkSel <= ChAi_ChunkSel;
			ChBo_ChunkSel <= ChBi_ChunkSel;
			ChAo_Inc <= ChAi_Inc;
			ChBo_Inc <= ChBi_Inc;
			ChAo_Init <= ChAi_Init;
			ChBo_Init <= ChBi_Init;
			ChAi_Rdy <= ChAo_Rdy;
			ChBi_Rdy <= ChBo_Rdy;
		else
			ChAo_AB_Buff <= ChBi_AB_Buff;
			ChBo_AB_Buff <= ChAi_AB_Buff;
			ChAo_D_i <= ChBi_D_i;
			ChBo_D_i <= ChAi_D_i;
			ChAo_ChunkSel <= ChBi_ChunkSel;
			ChBo_ChunkSel <= ChAi_ChunkSel;
			ChAo_Inc <= ChBi_Inc;
			ChBo_Inc <= ChAi_Inc;
			ChAo_Init <= ChBi_Init;
			ChBo_Init <= ChAi_Init;
			ChAi_Rdy <= ChBo_Rdy;
			ChBi_Rdy <= ChAo_Rdy;
		end if;
	end if;
end process;

process(Clk)
begin
	if(rising_edge(clk))then
		if(sgn_Get='0')then
			ChAo_Get <= ChAi_Get;
			ChBo_Get <= ChBi_Get;
			ChAo_GetIdx <= ChAi_GetIdx;
			ChBo_GetIdx <= ChBi_GetIdx;
			ChAi_Cnt_o <= ChAo_Cnt_o;
			ChBi_Cnt_o <= ChBo_Cnt_o;
		else
			ChAo_Get <= ChBi_Get;
			ChBo_Get <= ChAi_Get;
			ChAo_GetIdx <= ChBi_GetIdx;
			ChBo_GetIdx <= ChAi_GetIdx;
			ChAi_Cnt_o <= ChBo_Cnt_o;
			ChBi_Cnt_o <= ChAo_Cnt_o;
		end if;
	end if;
end process;

-- config
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_Inc <= '0';
		sgn_Get <= '0';
	elsif(rising_edge(clk))then
		if(M_Config='1')then
			sgn_Inc <= M_IncSet;
			sgn_Get <= M_GetSet;
		elsif(S_Config='1')then
			sgn_Inc <= S_IncSet;
			sgn_Get <= S_GetSet;
		end if;
	end if;
end process;

end rtl;

