----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    15/06/2018 
-- Design Name: 
-- Module Name:    Equihash_BucketMem_Mix - Behavioral
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

entity Equihash_BucketMem_Mix is
port (
	ChAi_A				: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChAi_D				: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChAi_Wr				: in	std_logic;
	
	ChBi_A				: in	unsigned(gcst_WA_Mem-1 downto 0);
	ChBi_D				: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChBi_Wr				: in	std_logic;
	
	Cho_A				: out	unsigned(gcst_WA_Mem-1 downto 0);
	Cho_D				: out	unsigned(gcst_WD_Mem-1 downto 0);
	Cho_Wr				: out	std_logic;
	
	M_Config			: in	std_logic; -- high priority
	M_ChSel				: in	std_logic; -- '0': A->o; '1': B->o
	
	S_Config			: in	std_logic;
	S_ChSel				: in	std_logic; -- '0': A->o; '1': B->o
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_BucketMem_Mix;

architecture rtl of Equihash_BucketMem_Mix is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_ChSel		: std_logic;
--============================ function declare ============================--

begin
-- channel mix
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_ChSel='0')then
			Cho_A <= ChAi_A;
			Cho_D <= ChAi_D;
			Cho_Wr <= ChAi_Wr;
		else
			Cho_A <= ChBi_A;
			Cho_D <= ChBi_D;
			Cho_Wr <= ChBi_Wr;
		end if;
	end if;
end process;

-- config
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_ChSel <= '0';
	elsif(rising_edge(clk))then
		if(M_Config='1')then
			sgn_ChSel <= M_ChSel;
		elsif(S_Config='1')then
			sgn_ChSel <= S_ChSel;
		end if;
	end if;
end process;

end rtl;

