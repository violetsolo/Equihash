----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    22/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UnCRam - Behavioral
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

--LIBRARY altera_mf;
--USE altera_mf.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

library work;
use work.LgGlobal_pkg.all;
use work.Equihash_pkg.all;

entity Equihash_GBP_UnCRam is
generic(
	Device_Family	: string := "Cyclone V";
	Num_Ch			: Natural := 5
);
port (
	Wr			: in	unsigned(Num_Ch-1 downto 0);
	A_Wr		: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Di			: in	typ_1D_Idx_D(Num_Ch-1 downto 0); -- index 4word
	A_Rd		: in	typ_1D_Idx_A(Num_Ch-1 downto 0);
	Do			: out	unsigned(gcst_WD_Idx-1 downto 0);
	
	SelCh		: in	unsigned(Num_Ch-1 downto 0);
	SelRam		: in	unsigned(Num_Ch-1 downto 0); -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Equihash_GBP_UnCRam;

architecture rtl of Equihash_GBP_UnCRam is
--============================ constant declare ============================--

--======================== Altera component declare ========================--
component altsyncram
generic (
	address_aclr_b					:	string := "NONE";
	address_reg_b					:	string := "CLOCK0";
	clock_enable_input_a			:	string := "BYPASS";
	clock_enable_input_b			:	string := "BYPASS";
	clock_enable_output_b			:	string := "BYPASS";
	intended_device_family			:	string := Device_Family;--"Cyclone V";
	lpm_type						:	string := "altsyncram";
	operation_mode					:	string := "DUAL_PORT";
	outdata_aclr_b					:	string := "NONE";
	outdata_reg_b					:	string := "CLOCK0";
	power_up_uninitialized			:	string := "FALSE";
	read_during_write_mode_mixed_ports	:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a						:	natural := gcst_Size_Idx;
	numwords_b						:	natural := gcst_Size_Idx;
	width_a							:	natural := gcst_WD_Idx;
	width_b							:	natural := gcst_WD_Idx;
	widthad_a						:	natural := gcst_WA_Idx; -- log2(128)
	widthad_b						:	natural := gcst_WA_Idx; -- log2(128)
	width_byteena_a					:	natural := 1
);
port(
	address_a	:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		:	in std_logic_vector(width_a-1 downto 0);
	wren_a		:	in std_logic;
	
	address_b	:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		:	in std_logic
);
end component;

component Lg_BoolOpt
generic(
	Num				: Positive := Num_Ch;
	Typ				: string := "or"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Mux_nL1b_T2
generic(
	Num				: Positive := Num_Ch;
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	Sel			: in	unsigned(Num-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '1'
);
end component;
--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_RamA_Do			: std_logic_vector(gcst_WD_Idx-1 downto 0);
signal sgn_RamA_A_Rd		: std_logic_vector(gcst_WA_Idx-1 downto 0);
signal sgn_RamA_Di			: std_logic_vector(gcst_WD_Idx-1 downto 0);
signal sgn_RamA_A_Wr		: std_logic_vector(gcst_WA_Idx-1 downto 0);
signal sgn_RamA_Wr			: std_logic;
signal sgn_RamB_Do			: std_logic_vector(gcst_WD_Idx-1 downto 0);
signal sgn_RamB_A_Rd		: std_logic_vector(gcst_WA_Idx-1 downto 0);
signal sgn_RamB_Di			: std_logic_vector(gcst_WD_Idx-1 downto 0);
signal sgn_RamB_A_Wr		: std_logic_vector(gcst_WA_Idx-1 downto 0);
signal sgn_RamB_Wr			: std_logic;

type typ_1D_Fmt is array (natural range <>) of unsigned(Num_Ch-1 downto 0);
signal sgn_Di				: typ_1D_Fmt(gcst_WD_Idx-1 downto 0);
signal sgn_A_Wr				: typ_1D_Fmt(gcst_WA_Idx-1 downto 0);
signal sgn_A_Rd				: typ_1D_Fmt(gcst_WA_Idx-1 downto 0);


signal sgn_SelRam			: std_logic;
signal sgn_SelRam_t			: unsigned(Num_Ch-1 downto 0);

signal sgn_Mux_A_Rd			: unsigned(gcst_WA_Idx-1 downto 0);
signal sgn_Mux_Di			: unsigned(gcst_WD_Idx-1 downto 0);
signal sgn_Mux_A_Wr			: unsigned(gcst_WA_Idx-1 downto 0);
signal sgn_Mux_Wr			: std_logic;
--============================ function declare ============================--

begin

inst01: altsyncram
port map(
	address_a	=> sgn_RamA_A_Wr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_RamA_Di,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_RamA_Wr,--:	in std_logic;
	
	address_b	=> sgn_RamA_A_Rd,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_RamA_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

inst02: altsyncram
port map(
	address_a	=> sgn_RamB_A_Wr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_RamB_Di,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_RamB_Wr,--:	in std_logic;
	
	address_b	=> sgn_RamB_A_Rd,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_RamB_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

sgn_SelRam_t <= SelRam and SelCh;
inst03: Lg_BoolOpt
port map(
	Di			=> sgn_SelRam_t,--: in	unsigned(Num-1 downto 0);
	Do			=> sgn_SelRam,--: out	std_logic;
	
	clk			=> '0',--: in	std_logic;
	aclr		=> '0'--: in	std_logic
);

-- Do
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_SelRam = '0')then -- Bo
			Do <= unsigned(sgn_RamB_Do);
		else
			Do <= unsigned(sgn_RamA_Do);
		end if;
	end if;
end process;

-- A_Rd A_Wr
i0100: for i in 0 to  gcst_WA_Idx-1 generate
	-- A_Rd
	inst04:Lg_Mux_nL1b_T2
	port map(
		Di			=> sgn_A_Rd(i),--: in	unsigned(Num-1 downto 0);
		Do			=> sgn_Mux_A_Rd(i),--: out	std_logic;
		Sel			=> SelCh,--: in	unsigned(Num-1 downto 0);
		
		clk			=> '0',--: in	std_logic;
		aclr		=> '0'--: in	std_logic := '1'
	);
	-- A_Wr
	inst05:Lg_Mux_nL1b_T2
	port map(
		Di			=> sgn_A_Wr(i),--: in	unsigned(Num-1 downto 0);
		Do			=> sgn_Mux_A_Wr(i),--: out	std_logic;
		Sel			=> SelCh,--: in	unsigned(Num-1 downto 0);
		
		clk			=> '0',--: in	std_logic;
		aclr		=> '0'--: in	std_logic := '1'
	);
end generate i0100;

i1100: for i in 0 to gcst_WA_Idx-1 generate
	i1110: for j in 0 to Num_Ch-1 generate
		sgn_A_Rd(i)(j) <= A_Rd(j)(i);
		sgn_A_Wr(i)(j) <= A_Wr(j)(i);
	end generate i1110;
end generate i1100;

--  Di
i0200: for i in 0 to  gcst_WD_Idx-1 generate
	inst06:Lg_Mux_nL1b_T2
	port map(
		Di			=> sgn_Di(i),--: in	unsigned(Num-1 downto 0);
		Do			=> sgn_Mux_Di(i),--: out	std_logic;
		Sel			=> SelCh,--: in	unsigned(Num-1 downto 0);
		
		clk			=> '0',--: in	std_logic;
		aclr		=> '0'--: in	std_logic := '1'
	);
end generate i0200;

i1200: for i in 0 to gcst_WD_Idx-1 generate
	i1210: for j in 0 to Num_Ch-1 generate
		sgn_Di(i)(j) <= Di(j)(i);
	end generate i1210;
end generate i1200;

--  Wr
inst07:Lg_Mux_nL1b_T2
port map(
	Di			=> Wr,--: in	unsigned(Num-1 downto 0);
	Do			=> sgn_Mux_Wr,--: out	std_logic;
	Sel			=> SelCh,--: in	unsigned(Num-1 downto 0);
	
	clk			=> '0',--: in	std_logic;
	aclr		=> '0'--: in	std_logic := '1'
);

-- connect to ram
process(clk)
begin
	if(rising_edge(clk))then
		sgn_RamA_Di <= std_logic_vector(sgn_Mux_Di);
		sgn_RamB_Di <= std_logic_vector(sgn_Mux_Di);
		sgn_RamA_A_Wr <= std_logic_vector(sgn_Mux_A_Wr);
		sgn_RamB_A_Wr <= std_logic_vector(sgn_Mux_A_Wr);
		sgn_RamA_A_Rd <= std_logic_vector(sgn_Mux_A_Rd);
		sgn_RamB_A_Rd <= std_logic_vector(sgn_Mux_A_Rd);
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_RamA_Wr <= '0';
		sgn_RamB_Wr <= '0';
	elsif(rising_edge(clk))then
		if(sgn_SelRam = '0')then -- Ai
			sgn_RamA_Wr <= sgn_Mux_Wr;
			sgn_RamB_Wr <= '0';
		else
			sgn_RamA_Wr <= '0';
			sgn_RamB_Wr <= sgn_Mux_Wr;
		end if;
	end if;
end process;

end rtl;

