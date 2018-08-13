----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    04/06/2018 
-- Design Name: 
-- Module Name:    Blake2b_Mix_Gx4 - Behavioral
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

entity Blake2b_Mix_Gx4 is
generic(
	Rn		 	: Natural range 0 to gcst_Blake_Round-1:= 1; -- 0~11
	Gn			: Natural range 0 to gcst_Blake_Gn-1:= 1; -- 0/1
	Vn			: Natural range 0 to gcst_Blake_Vn-1:= 0 -- 0/1
);
port (
	v_i			: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_i			: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	v_o			: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_o			: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	En			: in	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Blake2b_Mix_Gx4;

architecture rtl of Blake2b_Mix_Gx4 is
--============================ constant declare ============================--
constant cst_Num_G		: Positive := 4;
constant cst_Num_vSect	: Positive := gcst_Blake_SubWn/cst_Num_G; --4
constant cst_Num_GSect	: Positive := gcst_Blake_SubWn/cst_Num_G/gcst_Blake_Gn; --2

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Blake2b_Mix_G
generic(
	Ror1		: Positive; --32/16
	Ror2		: Positive --24/63
);
port (
	Va_i		: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vb_i		: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vc_i		: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vd_i		: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	x_i			: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	Va_o		: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vb_o		: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vc_o		: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	Vd_o		: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
	
	En			: in	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;
--============================= signal declare =============================--
signal sgn_Vi				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_Vo				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_m_i				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);

type typ_2D_mDL is array (natural range<>) of typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_m_DL			: typ_2D_mDL(gcst_Blake_MixGDL-1 downto 0);
--============================ function declare ============================--

begin

-- step 1
i0100: for i in 0 to gcst_Blake_SubWn-1 generate
	sgn_Vi(i) <= v_i(cst_VMix_Tbl(Gn, i));
end generate i0100;

i0200: for i in 0 to cst_Num_G-1 generate
	inst01: Blake2b_Mix_G
	generic map(
		Ror1		=> cst_ROR(Vn*2 + 0),--: Positive; --32/16
		Ror2		=> cst_ROR(Vn*2 + 1)--: Positive --24/63
	)
	port map(
		Va_i		=> sgn_Vi(i*cst_Num_vSect+0),--: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vb_i		=> sgn_Vi(i*cst_Num_vSect+1),--: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vc_i		=> sgn_Vi(i*cst_Num_vSect+2),--: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vd_i		=> sgn_Vi(i*cst_Num_vSect+3),--: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		
		x_i			=> sgn_m_i(cst_Sigma_Tbl(Rn, Gn * cst_Num_G * cst_Num_GSect + Vn + i*gcst_Blake_Vn)),--: in	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		
		Va_o		=> sgn_Vo(i*cst_Num_vSect+0),--: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vb_o		=> sgn_Vo(i*cst_Num_vSect+1),--: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vc_o		=> sgn_Vo(i*cst_Num_vSect+2),--: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		Vd_o		=> sgn_Vo(i*cst_Num_vSect+3),--: out	unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);
		
		En			=> En,--: in	std_logic;
		
		clk			=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0200;

i0300: for i in 0 to gcst_Blake_SubWn-1 generate
	v_o(cst_VMix_Tbl(Gn, i)) <= sgn_Vo(i);
end generate i0300;

-- delay
sgn_m_i <= m_i;
process(clk)
begin
	if(rising_edge(clk))then
		if(En='1')then
			sgn_m_DL(0) <= sgn_m_i;
			for i in 1 to gcst_Blake_MixGDL-1 loop
				sgn_m_DL(i) <= sgn_m_DL(i-1);
			end loop;
		end if;
	end if;
end process;

m_o <= sgn_m_DL(gcst_Blake_MixGDL-1);

end rtl;
