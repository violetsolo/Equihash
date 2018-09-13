----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    06/06/2018 
-- Design Name: 
-- Module Name:    Blake2b_Mix - Behavioral
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

entity Blake2b_Mix is
port (
	v_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	v_o		: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	En		: in	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic := '0'
);
end Blake2b_Mix;

architecture rtl of Blake2b_Mix is
--============================ constant declare ============================--
constant cst_Gn		: Positive := 2;
constant cst_Vn		: Positive := 2;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Blake2b_Mix_Gx4
generic(
	Rn		: Natural range 0 to gcst_Blake_Round-1; -- 0~11
	Gn		: Natural range 0 to gcst_Blake_Gn-1; -- 0/1
	Vn		: Natural range 0 to gcst_Blake_Vn-1 -- 0/1
);
port (
	v_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	v_o		: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_o		: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	En		: in	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic := '0'
);
end component;
--============================= signal declare =============================--
type typ_2D_V is array (natural range<>) of typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_V		: typ_2D_V(gcst_Blake_Round*gcst_Blake_Gn*gcst_Blake_Vn downto 0);
type typ_2D_m is array (natural range<>) of typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_m		: typ_2D_m(gcst_Blake_Round*gcst_Blake_Gn*gcst_Blake_Vn downto 0);
--============================ function declare ============================--

begin

sgn_V(0) <= v_i;
sgn_m(0) <= m_i;

i0100: for i in 0 to gcst_Blake_Round-1 generate
	i0110: for j in 0 to gcst_Blake_Gn-1 generate
		i0111: for k in 0 to gcst_Blake_Vn-1 generate
			inst01: Blake2b_Mix_Gx4
			generic map(
				Rn		=> i,--: Natural range 0 to gcst_Blake_Round-1; -- 0~11
				Gn		=> j,--: Natural range 0 to gcst_Blake_Gn-1; -- 0/1
				Vn		=> k--: Natural range 0 to gcst_Blake_Vn-1 -- 0/1
			)
			port map(
				v_i		=> sgn_V(i*gcst_Blake_Gn*gcst_Blake_Vn + j*gcst_Blake_Vn + k),--: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
				m_i		=> sgn_m(i*gcst_Blake_Gn*gcst_Blake_Vn + j*gcst_Blake_Vn + k),--: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
				
				v_o		=> sgn_V(i*gcst_Blake_Gn*gcst_Blake_Vn + j*gcst_Blake_Vn + k+1),--: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
				m_o		=> sgn_m(i*gcst_Blake_Gn*gcst_Blake_Vn + j*gcst_Blake_Vn + k+1),--: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
				
				En		=> En,--: in	std_logic;
				
				clk		=> clk,--: in	std_logic;
				aclr	=> aclr--: in	std_logic := '0'
			);
		end generate i0111;
	end generate i0110;
end generate i0100;

v_o <= sgn_V(gcst_Blake_Round*gcst_Blake_Gn*gcst_Blake_Vn);

end rtl;
