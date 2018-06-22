----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    06/06/2018 
-- Design Name: 
-- Module Name:    Blake2b_Lite - Behavioral
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

entity Blake2b_Lite is
port (
	Param		: in	typ_Blake_Param; -- must be hold until calculate finish
	msg_i		: in	typ_1D_Word(gcst_Blake_WW-1 downto 0); -- 128-byte (16 double word) chunk of message to compress
	isLast	: in	std_logic := '1'; -- '0' not last data '1' last data Indicates if this is the final round of compression
	Count		: in	unsigned(2*gcst_Blake_SubWW*gcst_WW-1 downto 0); -- 16B=128b Count of bytes that have been fed into the Compression
	
	hash_o	: out	typ_1D_Word(gcst_Blake_WW/2-1 downto 0); -- 64B
	
	clk		: in	std_logic;
	sclr		: in	std_logic := '0';
	aclr		: in	std_logic := '0'
);
end Blake2b_Lite;

architecture rtl of Blake2b_Lite is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Blake2b_Mix
port (
	v_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_i		: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	v_o		: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	clk		: in	std_logic;
	sclr		: in	std_logic := '0';
	aclr		: in	std_logic := '0'
);
end component;
--============================= signal declare =============================--
signal sgn_Param			: typ_1D_Word(gcst_Blake_WW/2-1 downto 0);
signal sgn_V_t				: typ_1D_Word(gcst_Blake_WW-1 downto 0);
signal sgn_V_i				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_m_i				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_V_o				: typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
signal sgn_V_o_Fmt		: typ_1D_Word(gcst_Blake_WW-1 downto 0);
signal sgn_Res				: typ_1D_Word(gcst_Blake_WW/2-1 downto 0);
--============================ function declare ============================--

begin

-- p xor iv xor
sgn_Param(0) <= Param.Digest_Len;
sgn_Param(1) <= Param.Key_Len;
sgn_Param(2) <= Param.Fanout;
sgn_Param(3) <= Param.Deepth;
i1100: for i in 0 to 4-1 generate
	sgn_Param(i+4) <= Param.Leaf_Len((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1100;
i1200: for i in 0 to 4-1 generate
	sgn_Param(i+8) <= Param.Node_Offset((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1200;
i1300: for i in 0 to 4-1 generate
	sgn_Param(i+12) <= Param.Xof_Len((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1300;
sgn_Param(16) <= Param.Node_Deepth;
sgn_Param(17) <= Param.Inner_Len;
i1400: for i in 0 to 14-1 generate
	sgn_Param(i+18) <= Param.Rvs((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1400;
i1500: for i in 0 to 16-1 generate
	sgn_Param(i+32) <= Param.Salt((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1500;
i1600: for i in 0 to 16-1 generate
	sgn_Param(i+48) <= Param.Personalization((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i1600;

i0100: for i in 0 to gcst_Blake_WW/2-1 generate
	sgn_V_t(i) <= sgn_Param(i) xor cst_IV_Tbl(i);
end generate i0100;

i0200: for i in 0 to gcst_Blake_WW/2-1 generate
	i0210: if(i >= 7 * gcst_Blake_SubWW or i < 4*gcst_Blake_SubWW)generate
		sgn_V_t(i + gcst_Blake_WW/2) <= cst_IV_Tbl(i);
	end generate i0210;
	
	i0220: if(i >= 4 * gcst_Blake_SubWW and i < 6 * gcst_Blake_SubWW)generate -- V12 xor count(L) / V13 xor count(H)
		sgn_V_t(i + gcst_Blake_WW/2) <= cst_IV_Tbl(i) xor Count((i-4 * gcst_Blake_SubWW+1)*gcst_WW-1 downto (i-4 * gcst_Blake_SubWW)*gcst_WW);
	end generate i0220;
		
	i0230: if(i >= 6 * gcst_Blake_SubWW and i < 7 * gcst_Blake_SubWW)generate
		process(isLast) -- xor 0FFFFFFFF
		begin
			if(isLast='0')then
				sgn_V_t(i + gcst_Blake_WW/2) <= cst_IV_Tbl(i);
			else
				sgn_V_t(i + gcst_Blake_WW/2) <= cst_IV_Tbl(i) xor x"FF";
			end if;
		end process;
	end generate i0230;
end generate i0200;

i0300: for i in 0 to gcst_Blake_SubWn-1 generate
	sgn_V_i(i) <= 	sgn_V_t(i*gcst_Blake_SubWW+7) & 
						sgn_V_t(i*gcst_Blake_SubWW+6) & 
						sgn_V_t(i*gcst_Blake_SubWW+5) & 
						sgn_V_t(i*gcst_Blake_SubWW+4) & 
						sgn_V_t(i*gcst_Blake_SubWW+3) & 
						sgn_V_t(i*gcst_Blake_SubWW+2) & 
						sgn_V_t(i*gcst_Blake_SubWW+1) & 
						sgn_V_t(i*gcst_Blake_SubWW+0);
	sgn_m_i(i) <= 	msg_i(i*gcst_Blake_SubWW+7) & 
						msg_i(i*gcst_Blake_SubWW+6) & 
						msg_i(i*gcst_Blake_SubWW+5) & 
						msg_i(i*gcst_Blake_SubWW+4) & 
						msg_i(i*gcst_Blake_SubWW+3) & 
						msg_i(i*gcst_Blake_SubWW+2) & 
						msg_i(i*gcst_Blake_SubWW+1) & 
						msg_i(i*gcst_Blake_SubWW+0);
end generate i0300;

inst01: Blake2b_Mix
port map(
	v_i		=> sgn_V_i,--: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	m_i		=> sgn_m_i,--: in	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	v_o		=> sgn_V_o,--: out	typ_1D_Blake8W(gcst_Blake_SubWn-1 downto 0);
	
	clk		=> clk,--: in	std_logic;
	sclr		=> sclr,--: in	std_logic := '0';
	aclr		=> aclr--: in	std_logic := '0'
);

i0400: for i in 0 to gcst_Blake_SubWn-1 generate
	i0410: for j in 0 to gcst_Blake_SubWW-1 generate
		sgn_V_o_Fmt(i*gcst_Blake_SubWW + j) <= sgn_V_o(i)((j+1)*gcst_Blake_SubWW-1 downto j*gcst_Blake_SubWW);
	end generate i0410;
end generate i0400;

-- xor h0 and v0~7 v8~15
i0500: for i in 0 to gcst_Blake_WW/2-1 generate
	process(clk)
	begin
		if(rising_edge(clk))then
			sgn_Res(i) <= sgn_V_t(i) xor sgn_V_o_Fmt(i) xor sgn_V_o_Fmt(i+gcst_Blake_WW/2);
		end if;
	end process;
end generate i0500;

hash_o <= sgn_Res;

end rtl;

