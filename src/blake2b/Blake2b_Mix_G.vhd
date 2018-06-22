----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    04/06/2018 
-- Design Name: 
-- Module Name:    Blake2b_Mix_G - Behavioral
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
use work.Blake2b_pkg.all;

entity Blake2b_Mix_G is
generic(
	Ror1			: Positive := 32; --32/16
	Ror2			: Positive := 24 --24/63
);
port (
	Va_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vb_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vc_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vd_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	x_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	Va_o			: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vb_o			: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vc_o			: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vd_o			: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	clk		: in	std_logic;
	sclr		: in	std_logic := '0';
	aclr		: in	std_logic := '0'
);
end Blake2b_Mix_G;

architecture rtl of Blake2b_Mix_G is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_Va		: typ_1D_Blake8W(gcst_Blake_MixGDL downto 0);
signal sgn_Vb		: typ_1D_Blake8W(gcst_Blake_MixGDL downto 0);
signal sgn_Vc		: typ_1D_Blake8W(gcst_Blake_MixGDL downto 0);
signal sgn_Vd		: typ_1D_Blake8W(gcst_Blake_MixGDL downto 0);
signal sgn_x		: unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);

constant cst_RtlDL	: positive := gcst_Blake_MixGDL;
signal sclr_DL			: unsigned(cst_RtlDL-1 downto 0);
--============================ function declare ============================--

begin
sclr_DL(0) <= sclr;
s0100: if (cst_RtlDL > 1) generate
	process(aclr,clk)
	begin
		if(aclr='1')then
			sclr_DL(cst_RtlDL-1 downto 1) <= (others => '0');
		elsif(rising_edge(clk))then
			for i in 1 to cst_RtlDL-1 loop
				sclr_DL(i) <= sclr_DL(i-1);
			end loop;
		end if;
	end process;
end generate;

sgn_x <= x_i;
-- step 1
sgn_Va(0) <= Va_i;
sgn_Vb(0) <= Vb_i;
sgn_Vc(0) <= Vc_i;
sgn_Vd(0) <= Vd_i;
i0100: for i in 1 to gcst_Blake_MixGDL generate
	-- a/d
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_Va(i) <= (others => '0');
			sgn_Vd(i) <= (others => '0');
			sgn_Vc(i) <= (others => '0');
			sgn_Vb(i) <= (others => '0');
		elsif(rising_edge(clk))then
			if(sclr_DL(0)='1')then
				sgn_Va(i) <= (others => '0');
				sgn_Vd(i) <= (others => '0');
				sgn_Vc(i) <= (others => '0');
				sgn_Vb(i) <= (others => '0');
			else
				if(i=1)then
					sgn_Va(i) <= unsigned(sgn_Va(i-1)) + unsigned(sgn_Vb(i-1)) + unsigned(sgn_x);
				else
					sgn_Va(i) <= sgn_Va(i-1);
				end if;
				if(i=2)then
					sgn_Vd(i) <= unsigned(sgn_Va(i-1) xor sgn_Vd(i-1)) ror Ror1;
				else
					sgn_Vd(i) <= sgn_Vd(i-1);
				end if;
				if(i=3)then
					sgn_Vc(i) <= unsigned(sgn_Vc(i-1)) + unsigned(sgn_Vd(i-1));
				else
					sgn_Vc(i) <= sgn_Vc(i-1);
				end if;
				if(i=4)then
					sgn_Vb(i) <= unsigned(sgn_Vc(i-1) xor sgn_Vb(i-1)) ror ROR2;
				else
					sgn_Vb(i) <= sgn_Vb(i-1);
				end if;
			end if;
		end if;
	end process;
	
	-- c/b
	process(clk,aclr)
	begin
		if(aclr='1')then
		elsif(rising_edge(clk))then
			if(sclr_DL(1)='1')then
			else
			end if;
		end if;
	end process;
end generate i0100;

Va_o <= sgn_Va(gcst_Blake_MixGDL);
Vb_o <= sgn_Vb(gcst_Blake_MixGDL);
Vc_o <= sgn_Vc(gcst_Blake_MixGDL);
Vd_o <= sgn_Vd(gcst_Blake_MixGDL);
end rtl;

