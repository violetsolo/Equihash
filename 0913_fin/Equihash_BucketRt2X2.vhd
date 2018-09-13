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
	Chi_AB_Buff			: in	unsigned(gcst_WA_Mem-1 downto 0);
	Chi_Get				: in	std_logic;
	Chi_GetIdx			: in	unsigned(gcst_W_Chunk-1 downto 0);
	Chi_D_i				: in	unsigned(gcst_WD_Mem-1 downto 0);
	Chi_ChunkSel		: in	Natural range 0 to gcst_N_Chunk-1;
	Chi_Inc				: in	std_logic;
	Chi_Init			: in	std_logic;
	Chi_Cnt_o			: out	Natural range 0 to Max_Counter;
	Chi_Rdy				: out	std_logic;
	
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
	M_IncSet			: in	std_logic; -- '0': i->A; '1': i->B
	M_GetSet			: in	std_logic; -- '0': i->A; '1': i->B
	
	S_Config			: in	std_logic;
	S_IncSet			: in	std_logic; -- '0': i->A; '1': i->B
	S_GetSet			: in	std_logic; -- '0': i->A; '1': i->B
	
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
		ChAo_AB_Buff <= Chi_AB_Buff;
		ChBo_AB_Buff <= Chi_AB_Buff;
		ChAo_D_i <= Chi_D_i;
		ChBo_D_i <= Chi_D_i;
		ChAo_ChunkSel <= Chi_ChunkSel;
		ChBo_ChunkSel <= Chi_ChunkSel;
		if(sgn_Inc='0')then
			ChAo_Inc <= Chi_Inc;
			ChBo_Inc <= '0';
			ChAo_Init <= Chi_Init;
			ChBo_Init <= '0';
			Chi_Rdy <= ChAo_Rdy;
		else
			ChAo_Inc <= '0';
			ChBo_Inc <= Chi_Inc;
			ChAo_Init <= '0';
			ChBo_Init <= Chi_Init;
			Chi_Rdy <= ChBo_Rdy;
		end if;
	end if;
end process;

process(Clk)
begin
	if(rising_edge(clk))then
		ChAo_GetIdx <= Chi_GetIdx;
		ChBo_GetIdx <= Chi_GetIdx;
		if(sgn_Get='0')then
			ChAo_Get <= Chi_Get;
			ChBo_Get <= '0';
			Chi_Cnt_o <= ChAo_Cnt_o;
		else
			ChAo_Get <= '0';
			ChBo_Get <= Chi_Get;
			Chi_Cnt_o <= ChBo_Cnt_o;
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

