----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Lg_BMix_MidWare_DCross - Behavioral
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
use work.Lg_BMix_MidWare_pkg.all;

entity Lg_BMix_MidWare_DCross is
generic(
	NumExpo_Ch_i			: Positive := 5;
	NumExpo_Ch_o			: Positive := 4
);
port (
	Data_i		: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i		: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		: in	unsigned(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		: out	unsigned(2**NumExpo_Ch_o-1 downto 0);

	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Lg_BMix_MidWare_DCross;

architecture rtl of Lg_BMix_MidWare_DCross is
--============================ constant declare ============================--
constant cst_NumCh_i		: Positive := 2**NumExpo_Ch_i;
constant cst_NumCh_o		: Positive := 2**NumExpo_Ch_o;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Lg_Dsp_nL1b_T1
generic(
	Num			: Positive := cst_NumCh_o;
	Syn			: string := "false" -- "true" "false"
);
port (
	Di			: in	std_logic;
	Do			: out	unsigned(Num-1 downto 0);
	Sel			: in	Natural;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Mux_nL1b_T2
generic(
	Num			: Positive := cst_NumCh_i;
	Syn			: string := "false" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	Sel			: in	unsigned(Num-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	Num			: Positive := cst_NumCh_i;
	Typ			: string	:= "or"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn			: string := "false" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
type typ_2D_Data_Dsp		is array (natural range<>, natural range<>) of unsigned(cst_NumCh_o-1 downto 0);
signal sgn_Data_DspRes		: typ_2D_Data_Dsp(cst_NumCh_i-1 downto 0, gcst_AM_WidthData-1 downto 0);
type typ_2D_Data_Mux		is array (natural range<>, natural range<>) of unsigned(cst_NumCh_i-1 downto 0);
signal sgn_Data_MuxIn		: typ_2D_Data_Mux(cst_NumCh_o-1 downto 0, gcst_AM_WidthData-1 downto 0);

type typ_1D_Flag_Dsp		is array (natural range<>) of unsigned(cst_NumCh_o-1 downto 0);
signal sgn_Flag_DspRes		: typ_1D_Flag_Dsp(cst_NumCh_i-1 downto 0);
type typ_1D_Flag_Mux		is array (natural range<>) of unsigned(cst_NumCh_i-1 downto 0);
signal sgn_Flag_MuxIn		: typ_1D_Flag_Mux(cst_NumCh_o-1 downto 0);

signal sgn_Data_o			: typ_AM_1D_Data(cst_NumCh_o-1 downto 0);
signal sgn_Flag_o			: unsigned(cst_NumCh_o-1 downto 0);

signal sgn_Data_i			: typ_AM_1D_Data(cst_NumCh_i-1 downto 0);
signal sgn_Ch_i				: typ_1D_Word(cst_NumCh_i-1 downto 0); -- 0 to Num_Ch_o-1
signal sgn_Flag_i			: unsigned(cst_NumCh_i-1 downto 0);
--============================ function declare ============================--

--=========================== attribute declare ============================--

begin
--process(aclr,clk)
--begin
--	if(aclr='1')then
--	
--	elsif(rising_edge(clk))then
	sgn_Data_i <= Data_i;
	sgn_Ch_i <= Ch_i;
	sgn_Flag_i <= Flag_i;
--	end if;
--end process;

-- data dispatch according to ch
i0100: for i in 0 to cst_NumCh_i-1 generate
	i0110: for j in 0 to gcst_AM_WidthData-1 generate
		i0111: for k in 0 to cst_NumCh_o-1 generate
			sgn_Data_DspRes(i,j)(k) <= sgn_Data_i(i)(j);
		end generate i0111;
	end generate i0110;
	inst02: Lg_Dsp_nL1b_T1
	port map(
		Di			=> sgn_Flag_i(i),--: in	std_logic;
		Do			=> sgn_Flag_DspRes(i),--: out	unsigned(2**nL-1 downto 0);
		Sel			=> to_integer(sgn_Ch_i(i)(NumExpo_Ch_o-1 downto 0)),--: in	Natural;
		
		clk			=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0100;

-- data trans
i0200: for i in 0 to cst_NumCh_i-1 generate
	i0210: for j in 0 to cst_NumCh_o-1 generate
		i0211:for k in 0 to gcst_AM_WidthData-1 generate
			sgn_Data_MuxIn(j,k)(i) <= sgn_Data_DspRes(i,k)(j);
		end generate i0211;
			sgn_Flag_MuxIn(j)(i) <= sgn_Flag_DspRes(i)(j);
	end generate i0210;
end generate i0200;

-- data select according to flag
i0300: for i in 0 to cst_NumCh_o-1 generate
	i0310: for j in 0 to gcst_AM_WidthData-1 generate
		inst03: Lg_Mux_nL1b_T2
		port map(
			Di			=> sgn_Data_MuxIn(i,j),--: in	unsigned(2**nL-1 downto 0);
			Do			=> sgn_Data_o(i)(j),--: out	std_logic;
			Sel			=> sgn_Flag_MuxIn(i),--: in	unsigned(2**nL-1 downto 0);
			
			clk			=> clk,--: in	std_logic;
			aclr		=> aclr--: in	std_logic
		);
	end generate i0310;
	inst04: Lg_BoolOpt
	port map(
		Di			=> sgn_Flag_MuxIn(i),--: in	unsigned(2**nL-1 downto 0);
		Do			=> sgn_Flag_o(i),--: out	std_logic;
		
		clk			=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0300;

process(aclr,clk)
begin
	if(aclr='1')then
		Flag_o <= (others => '0');
		Data_o <= (others => (others => '0'));
	elsif(rising_edge(clk))then
		Flag_o <= sgn_Flag_o;
		Data_o <= sgn_Data_o;
	end if;
end process;

end rtl;
