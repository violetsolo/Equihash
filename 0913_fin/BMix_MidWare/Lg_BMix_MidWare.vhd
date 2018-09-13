----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Lg_BMix_MidWare - Behavioral
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

entity Lg_BMix_MidWare is
generic(
	NumExpo_Ch_i			: Positive := 2; -- must lager than NumExpo_Ch_o
	NumExpo_Ch_o			: Positive := 2;
	InputRsv				: Positive := 12 -- must lager than 4
);
port (
	Data_i		: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i		: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		: in	unsigned(2**NumExpo_Ch_i-1 downto 0);
	Valid_i		: out	unsigned(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		: out	unsigned(2**NumExpo_Ch_o-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Lg_BMix_MidWare;

architecture rtl of Lg_BMix_MidWare is
--============================ constant declare ============================--
constant cst_NumCh_i			: Positive := 2**NumExpo_Ch_i; -- 32
constant cst_NumCh_o			: Positive := 2**NumExpo_Ch_o; -- 16
constant cst_Deepth_iRam		: Positive := 64; -- 64
constant cst_Deepth_oRam		: Positive := 2*cst_NumCh_i*gcst_AM_SelDL; -- 2*(32*3)=192
constant cst_DeepthExpo_iRam	: Positive := Fnc_Int2Wd(cst_Deepth_iRam-1); -- 6
constant cst_DeepthExpo_oRam	: Positive := Fnc_Int2Wd(cst_Deepth_oRam-1); -- 8
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Lg_BMix_MidWare_oRamAddrGen
generic(
	WrGen_N			: Positive := cst_NumCh_i; -- 32
	WrGen_P			: Positive := 2;
	WrGen_L			: Positive := gcst_AM_SelDL; -- 3
	RdRam_N			: Positive := cst_NumCh_i; -- 32
	RdRam_P			: Positive := gcst_AM_SelDL * 2; -- 6
	WrGen_DL		: Positive := gcst_AM_SeloRamDL; -- 4
	RdGen_DL		: Positive := cst_NumCh_i*gcst_AM_SelDL+gcst_AM_SeloRamDL -- 32*3+4
);
port (
	Addr_Wr		: out	Natural;
	Addr_Rd		: out	typ_1D_Nat(RdRam_N-1 downto 0);
	Msk_clr		: out	std_logic;
	
	En			: in	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_BMix_MidWare_Cell
generic(
	Device_Family		: string := "Cyclone V"; --"Stratix 10";--"Cyclone V"
	Width_Data			: Positive := gcst_AM_WidthData;
	Num_Ch				: Positive := cst_NumCh_i;
	DeepthExpo_iRam		: Positive := cst_DeepthExpo_iRam; -- 64 = 2^6
	DeepthExpo_oRam		: Positive := cst_DeepthExpo_oRam; -- 256 = 2^8
	InputRsv_iRam		: Positive := InputRsv -- must lager than 4
);
port (
	Data_i			: in	unsigned(Width_Data-1 downto 0);
	Ch_i			: in	unsigned(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Wr				: in	std_logic;
	Valid			: out	std_logic;
	
	Data_o			: out	unsigned(Width_Data-1 downto 0);
	Ch_o			: out	unsigned(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Flag_o			: out	std_logic;
	
	oRam_AddrWr		: in	unsigned(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	oRam_AddrRd		: in	unsigned(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	
	Msk_Clr			: in	std_logic;
	Msk_i			: in	unsigned(Num_Ch-1 downto 0);
	Msk_o			: out	unsigned(Num_Ch-1 downto 0);
	
	AcsMid_Valid	: out std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Lg_BMix_MidWare_DCross
generic(
	NumExpo_Ch_i			: Positive := NumExpo_Ch_i;
	NumExpo_Ch_o			: Positive := NumExpo_Ch_o
);
port (
	Data_i			: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i			: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i			: in	unsigned(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o			: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o			: out	unsigned(2**NumExpo_Ch_o-1 downto 0);

	clk				: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	Num				: Positive := cst_NumCh_i;
	Typ				: string := "and"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_oRam_AddrWr			: Natural;
signal sgn_oRam_AddrRd			: typ_1D_Nat(cst_NumCh_i-1 downto 0);
signal sgn_Msk_clr				: std_logic;

signal sgn_AcsMid_Valid			: unsigned(cst_NumCh_i-1 downto 0);
signal sgn_AcsMid_Valid_tot		: std_logic;

type typ_1D_Msk is array (natural range<>) of unsigned(cst_NumCh_i-1 downto 0);
signal sgn_Msk_i				: typ_1D_Msk(cst_NumCh_i-1 downto 0);
signal sgn_Msk_o				: typ_1D_Msk(cst_NumCh_i-1 downto 0);

signal sgn_Data_Sel				: typ_AM_1D_Data(cst_NumCh_i-1 downto 0);
signal sgn_Ch_Sel				: typ_1D_Word(cst_NumCh_i-1 downto 0); -- 0 to Num_Ch_o-1
signal sgn_Flag_Sel				: unsigned(cst_NumCh_i-1 downto 0);

signal sgn_oRam_AddrWr_Fmt		: unsigned(cst_DeepthExpo_oRam-1 downto 0);
type typ_oRamAddrWrFmt is array (natural range<>) of unsigned(cst_DeepthExpo_oRam-1 downto 0);
signal sgn_oRam_AddrRd_Fmt		: typ_oRamAddrWrFmt(cst_NumCh_i-1 downto 0);
--============================ function declare ============================--

--=========================== attribute declare ============================--

begin

inst01: Lg_BMix_MidWare_oRamAddrGen
port map(
	Addr_Wr		=> sgn_oRam_AddrWr,--: out	Natural;
	Addr_Rd		=> sgn_oRam_AddrRd,--: out	typ_1D_Nat(RdRam_N-1 downto 0);
	Msk_clr		=> sgn_Msk_clr,--: out	std_logic;
	
	En				=> sgn_AcsMid_Valid_tot,--: in	std_logic;
	
	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst04:Lg_BoolOpt
port map(
	Di			=> sgn_AcsMid_Valid,--: in	std_logic_vector(2**nL-1 downto 0);
	Do			=> sgn_AcsMid_Valid_tot,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

i0100: for i in 0 to cst_NumCh_i-1 generate
	inst02: Lg_BMix_MidWare_Cell
	port map(
		Data_i			=> Data_i(i),--(io): in	std_logic_vector(Width_Data-1 downto 0);
		Ch_i			=> Ch_i(i),--(io): in	std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
		Wr				=> Flag_i(i),--(io): in	std_logic;
		Valid			=> Valid_i(i),--: out	std_logic;
		
		Data_o			=> sgn_Data_Sel(i),--: out	std_logic_vector(Width_Data-1 downto 0);
		Ch_o			=> sgn_Ch_Sel(i),--: out std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
		Flag_o			=> sgn_Flag_Sel(i),--: out std_logic;
		
		oRam_AddrWr		=> sgn_oRam_AddrWr_Fmt,--: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
		oRam_AddrRd		=> sgn_oRam_AddrRd_Fmt(i),--: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
		
		Msk_Clr			=> sgn_Msk_clr,--: in	std_logic;
		Msk_i			=> sgn_Msk_i(i),--: in	std_logic_vector(Num_Ch-1 downto 0);
		Msk_o			=> sgn_Msk_o(i),--: out	std_logic_vector(Num_Ch-1 downto 0);
		
		AcsMid_Valid	=> sgn_AcsMid_Valid(i),--: out std_logic;
		
		clk				=> clk,--: in	std_logic;
		aclr			=> aclr--: in	std_logic
	);
	sgn_oRam_AddrRd_Fmt(i) <= to_unsigned(sgn_oRam_AddrRd(i),cst_DeepthExpo_oRam);
end generate i0100;

sgn_oRam_AddrWr_Fmt <= to_unsigned(sgn_oRam_AddrWr,cst_DeepthExpo_oRam);

sgn_Msk_i(0) <= sgn_Msk_o(cst_NumCh_i-1);
i0200: for i in 1 to cst_NumCh_i-1 generate
	sgn_Msk_i(i) <= sgn_Msk_o(i-1);
end generate i0200;

inst03:Lg_BMix_MidWare_DCross
port map(
	Data_i			=> sgn_Data_Sel,--: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i			=> sgn_Ch_Sel,--: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i			=> sgn_Flag_Sel,--: in	std_logic_vector(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o			=> Data_o,--: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o			=> Flag_o,--: out	std_logic_vector(2**NumExpo_Ch_o-1 downto 0);

	clk				=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

end rtl;
