----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    07/06/2018 
-- Design Name: 
-- Module Name:    Lg_RamCounter - Behavioral
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

entity Lg_RamCounter is
generic(
	Device_Family	: string := "Cyclone V";
	Num_Cnt			: Natural := 2**12;
	Max_Cnt			: Natural := 2**8
);
port (
	Inc			: in	std_logic;
	Init		: in	std_logic;
	
	Idx_Cnt		: in	Natural range 0 to Num_Cnt-1;
	Cnt_o		: out	Natural range 0 to Max_Cnt;
	
	Rdy			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Lg_RamCounter;

architecture rtl of Lg_RamCounter is
--============================ constant declare ============================--
constant cst_Expo_NumCnt	: Natural := Fnc_Int2Wd(Num_Cnt-1);
constant cst_WidthCnt		: Natural := Fnc_Int2Wd(Max_Cnt);

constant cst_RamRd_DL		: Natural := 2;
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
	numwords_a						:	natural := Num_Cnt;
	numwords_b						:	natural := Num_Cnt;
	width_a							:	natural := cst_WidthCnt;
	width_b							:	natural := cst_WidthCnt;
	widthad_a						:	natural := cst_Expo_NumCnt; -- log2(128)
	widthad_b						:	natural := cst_Expo_NumCnt; -- log2(128)
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
--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_Ram_Data_Rd			: std_logic_vector(cst_WidthCnt-1 downto 0);
signal sgn_Ram_Addr_Rd			: std_logic_vector(cst_Expo_NumCnt-1 downto 0);
signal sgn_Ram_Data_Wr			: std_logic_vector(cst_WidthCnt-1 downto 0);
signal sgn_Ram_Addr_Wr			: std_logic_vector(cst_Expo_NumCnt-1 downto 0);
signal sgn_Ram_Wr				: std_logic;

signal sgn_Inc					: std_logic;
constant cst_Inc_DL				: Natural := cst_RamRd_DL+3;
signal sgn_Inc_DL				: unsigned(cst_Inc_DL-1 downto 0);
constant cst_Pos_DL				: Natural := cst_RamRd_DL+3;
signal sgn_Pos					: unsigned(Fnc_Int2Wd(Num_Cnt-1)-1 downto 0);
type typ_Pos_DL is array (cst_Pos_DL-1 downto 0) of unsigned(cst_Expo_NumCnt-1 downto 0);
signal sgn_Pos_DL				: typ_Pos_DL;
signal sgn_Data_DL				: std_logic_vector(cst_WidthCnt-1 downto 0);


signal sgn_CmpRes				: unsigned(cst_Pos_DL-3 downto 0);
signal sgn_CmpRes_t				: unsigned(cst_Pos_DL-3 downto 0);

signal sgn_Ram_Data_Wr_Int		: unsigned(cst_WidthCnt-1 downto 0);
signal sgn_Ram_Addr_Wr_Int		: unsigned(cst_Expo_NumCnt-1 downto 0);
signal sgn_Ram_Wr_Int			: std_logic;
signal sgn_IntSel				: std_logic; -- '0' initial

signal sgn_DInc_t				: unsigned(Fnc_Int2Wd(Max_Cnt+4)-1 downto 0);
signal sgn_DInc					: unsigned(cst_WidthCnt-1 downto 0);
signal sgn_m					: Natural;

type typ_state is (S_Idle, S_Init);
signal state 					: typ_state;

--============================ function declare ============================--

begin

inst01: altsyncram
port map(
	address_a	=> sgn_Ram_Addr_Wr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_Ram_Data_Wr,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Ram_Wr,--:	in std_logic;
	
	address_b	=> sgn_Ram_Addr_Rd,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Ram_Data_Rd,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

sgn_Ram_Addr_Rd <= std_logic_vector (sgn_Pos);
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Ram_Wr <= '0';
	elsif(rising_edge(clk))then
		if(sgn_IntSel='1')then
			sgn_Ram_Wr <= sgn_Inc_DL(1);
		else
			sgn_Ram_Wr <= sgn_Ram_Wr_Int;
		end if;
	end if;
end process;

process(clk,aclr)
begin
	if(rising_edge(clk))then
		if(sgn_IntSel='1')then
			sgn_Ram_Addr_Wr <= std_logic_vector(sgn_Pos_DL(1));
		else
			sgn_Ram_Addr_Wr <= std_logic_vector(sgn_Ram_Addr_Wr_Int);
		end if;
	end if;
end process;

sgn_Ram_Data_Wr <= std_logic_vector(sgn_DInc) when sgn_IntSel='1' else
				   std_logic_vector(sgn_Ram_Data_Wr_Int);

-- counter increase
i0100: for i in cst_RamRd_DL to cst_Pos_DL-1 generate
	sgn_CmpRes_t(i-cst_RamRd_DL) <= '1' when sgn_Pos_DL(cst_RamRd_DL-1)=sgn_Pos_DL(i) else '0';
	sgn_CmpRes(i-cst_RamRd_DL) <= sgn_CmpRes_t(i-cst_RamRd_DL) and sgn_Inc_DL(i) and sgn_Inc_DL(cst_RamRd_DL-1);
end generate i0100;

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Inc_DL(cst_RamRd_DL-1) = '1')then
			if(sgn_CmpRes = "111")then
					sgn_m <= 4;
			elsif(sgn_CmpRes = "000")then
					sgn_m <= 1;
			elsif(sgn_CmpRes = "001" or sgn_CmpRes = "010" or sgn_CmpRes = "100")then
					sgn_m <= 2;
			else
					sgn_m <= 3;
			end if;
		else
			sgn_m <= 0;
		end if;
	end if;
end process;

sgn_DInc_t <= unsigned(sgn_Data_DL) + sgn_m;
sgn_DInc <= sgn_DInc_t(sgn_DInc'range) when sgn_DInc_t <= Max_Cnt else 
			to_unsigned(Max_Cnt,sgn_DInc'length);

-- data out
process(clk)
begin
	if(rising_edge(clk))then
		Cnt_o <= to_integer(sgn_DInc);
	end if;
end process;

-- initial sm
sgn_Ram_Data_Wr_Int <= to_unsigned(0, sgn_Ram_Data_Wr_Int'length);
process(clk,aclr)
begin
	if(aclr='1')then
		state <= S_Init;
		sgn_Ram_Addr_Wr_Int <= to_unsigned(0, sgn_Ram_Addr_Wr_Int'length);
		sgn_Ram_Wr_Int <= '1';
		sgn_IntSel <= '0';
		Rdy <= '0';
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				sgn_Ram_Addr_Wr_Int <= to_unsigned(0, sgn_Ram_Addr_Wr_Int'length);
				if(Init='1')then
					state <= S_Init;
					sgn_Ram_Wr_Int <= '1';
					sgn_IntSel <= '0';
					Rdy <= '0';
				else
					sgn_Ram_Wr_Int <= '0';
					sgn_IntSel <= '1';
					Rdy <= '1';
				end if;
				
			when S_Init =>
				if(sgn_Ram_Addr_Wr_Int = Num_Cnt-1)then
					sgn_Ram_Wr_Int <= '0';
					state <= S_Idle;
				else
					sgn_Ram_Addr_Wr_Int <= sgn_Ram_Addr_Wr_Int + 1;
					sgn_Ram_Wr_Int <= '1';
				end if;
				
			when others => 
				state <= S_Idle;
				sgn_Ram_Addr_Wr_Int <= to_unsigned(0, sgn_Ram_Addr_Wr_Int'length);
				sgn_Ram_Wr_Int <= '0';
				sgn_IntSel <= '1';
		end case;
	end if;
end process;

-- delay
sgn_Inc <= Inc;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Inc_DL <= to_unsigned(0,sgn_Inc_DL'length);
	elsif(rising_edge(clk))then
		sgn_Inc_DL(0) <= sgn_Inc;
		for i in 1 to cst_Inc_DL-1 loop
			sgn_Inc_DL(i) <= sgn_Inc_DL(i-1);
		end loop;
	end if;
end process;

sgn_Pos <= to_unsigned(Idx_Cnt,Fnc_Int2Wd(Num_Cnt-1));
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Pos_DL(0) <= sgn_Pos;
		for i in 1 to cst_Pos_DL-1 loop
			sgn_Pos_DL(i) <= sgn_Pos_DL(i-1);
		end loop;
		sgn_Data_DL <= sgn_Ram_Data_Rd;
	end if;
end process;

end rtl;

