-- Copyright (C) 2017  Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License 
-- Subscription Agreement, the Intel Quartus Prime License Agreement,
-- the Intel FPGA IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Intel and sold by Intel or its authorized distributors.  Please
-- refer to the applicable agreement for further details.

-- ***************************************************************************
-- This file contains a Vhdl test bench template that is freely editable to   
-- suit user's needs .Comments are provided in each section to help the user  
-- fill out necessary details.                                                
-- ***************************************************************************
-- Generated on "06/28/2018 15:45:54"
                                                            
-- Vhdl Test Bench template for design  :  Equihash_PoW_Wrapper
-- 
-- Simulation tool : ModelSim-Altera (VHDL)
-- 

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

ENTITY Equihash_PoW_Wrapper_ram_vhd_tst IS
END Equihash_PoW_Wrapper_ram_vhd_tst;
ARCHITECTURE Equihash_PoW_Wrapper_arch OF Equihash_PoW_Wrapper_ram_vhd_tst IS
-- constants
constant period	: time := 10 ns;
constant Num_sThread		: Natural := 1;
constant Device_Family		: string := "Cyclone V";

constant cst_RamD_Num		: Natural := 2*gcst_mBucket_MaxCap*gcst_mBucket_Num;
constant cst_RamIdx_Num		: Natural := (gcst_Equihash_k+1)*(2**19+2**21);

constant cst_RamD_Au		: Natural := Fnc_Int2Wd(cst_RamD_Num);
constant cst_RamIdx_Au		: Natural := Fnc_Int2Wd(cst_RamIdx_Num);

constant cst_RamSect		: Natural := 32;
constant cst_RamSectNum		: Natural := gcst_WD_Mem/32;

--============================ DU declare ============================--
-- signals                                                   
signal Nounce			: typ_1D_Word(gcst_W_Nounce-1 downto 0); -- 32B
	-- read data from buffer (memory)
signal Mem_D_A_Rd		: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal Mem_D_Rd			: unsigned(Num_sThread-1 downto 0);
signal Mem_D_Di			: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal Mem_D_RdAck		: unsigned(Num_sThread-1 downto 0);
	-- write data into memory
signal Mem_D_A_Wr		: typ_1D_Mem_A(Num_sThread-1 downto 0);
signal Mem_D_Do			: typ_1D_Mem_D(Num_sThread-1 downto 0);
signal Mem_D_Wr			: unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
signal Mem_Idx_A_Rd		: unsigned(gcst_WA_Mem-1 downto 0);
signal Mem_Idx_Rd		: std_logic;
signal Mem_Idx_Di		: unsigned(gcst_WD_Mem_Apdix-1 downto 0);
signal Mem_Idx_RdAck	: std_logic;
	-- write index info into memory
signal Mem_Idx_A_Wr		: typ_1D_MemApdix_A(Num_sThread-1 downto 0);
signal Mem_Idx_Do		: typ_1D_MemApdix_D(Num_sThread-1 downto 0);
signal Mem_Idx_Wr		: unsigned(Num_sThread-1 downto 0);
	-- result
signal ResValid			: std_logic;
signal Res				: unsigned(gcst_WD_idxCache-1 downto 0);
	
signal St				: std_logic;
signal Ed				: std_logic;
	
signal clk				: std_logic;
signal aclr				: std_logic;
	
COMPONENT Equihash_PoW_Wrapper
generic(
	Device_Family		: string := Device_Family;
	Num_sThread			: Natural := Num_sThread
);
port (
	Nounce				: in	typ_1D_Word(gcst_W_Nounce-1 downto 0); -- 32B
	
	-- read data from buffer (memory)
	Mem_D_A_Rd			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_D_Rd			: out	unsigned(Num_sThread-1 downto 0);
	Mem_D_Di			: in	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_D_RdAck			: in	unsigned(Num_sThread-1 downto 0);
	-- write data into memory
	Mem_D_A_Wr			: out	typ_1D_Mem_A(Num_sThread-1 downto 0);
	Mem_D_Do			: out	typ_1D_Mem_D(Num_sThread-1 downto 0);
	Mem_D_Wr			: out	unsigned(Num_sThread-1 downto 0);
	-- read index from buffer (memory)
	Mem_Idx_A_Rd		: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Idx_Rd			: out	std_logic;
	Mem_Idx_Di			: in	unsigned(gcst_WD_Mem_Apdix-1 downto 0);
	Mem_Idx_RdAck		: in	std_logic;
	-- write index info into memory
	Mem_Idx_A_Wr		: out	typ_1D_MemApdix_A(Num_sThread-1 downto 0);
	Mem_Idx_Do			: out	typ_1D_MemApdix_D(Num_sThread-1 downto 0);
	Mem_Idx_Wr			: out	unsigned(Num_sThread-1 downto 0);
	-- result
	ResValid			: out	std_logic;
	Res					: out	unsigned(gcst_WD_idxCache-1 downto 0);
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
END COMPONENT;

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
	numwords_a						:	natural ;
	numwords_b						:	natural ;
	width_a							:	natural ;
	width_b							:	natural ;
	widthad_a						:	natural ;
	widthad_b						:	natural ;
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
component Lg_SingalPipe
generic(
	Width_D			: Positive;
	Num_Pipe		: Positive
);
port (
	di			: in	unsigned(Width_D-1 downto 0);
	do			: out	unsigned(Width_D-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_DP_Ram_Sc
generic (
	Data_Width : natural := 8;
	Data_Num 	: natural := 6
);
port (
	data	: in unsigned((Data_Width-1) downto 0);
	waddr	: in natural range 0 to Data_Num - 1;
	we		: in std_logic := '1';
	
	q		: out unsigned((Data_Width -1) downto 0);
	raddr	: in natural range 0 to Data_Num - 1;
	
	clk		: in std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Mem_D_Di			: std_logic_vector(gcst_WD_Mem-1 downto 0);
signal sgn_Mem_Idx_Di		: std_logic_vector(gcst_WD_idxCache-1 downto 0);

signal sgn_Mem_D_RdAck		: unsigned(0 downto 0);
signal sgn_Mem_Idx_RdAck	: unsigned(0 downto 0);
--============================ function declare ============================--

BEGIN
-- du
du01 : Equihash_PoW_Wrapper
	PORT MAP (
-- list connections between master ports and signals
	aclr => aclr,
	clk => clk,
	
	Mem_D_Do => Mem_D_Do,
	Mem_D_A_Wr => Mem_D_A_Wr,
	Mem_D_Wr => Mem_D_Wr,
	
	Mem_D_Di => Mem_D_Di,
	Mem_D_A_Rd => Mem_D_A_Rd,
	Mem_D_Rd => Mem_D_Rd,
	Mem_D_RdAck => Mem_D_RdAck,
	
	Mem_Idx_Do => Mem_Idx_Do,
	Mem_Idx_A_Wr => Mem_Idx_A_Wr,
	Mem_Idx_Wr => Mem_Idx_Wr,
	
	Mem_Idx_Di => Mem_Idx_Di,
	Mem_Idx_A_Rd => Mem_Idx_A_Rd,
	Mem_Idx_Rd => Mem_Idx_Rd,
	Mem_Idx_RdAck => Mem_Idx_RdAck,
	
	Nounce => Nounce,
	Res => Res,
	ResValid => ResValid,
	
	Ed => Ed,
	St => St
	);

-- clock generate
process
begin
	clk <= '1';
	wait for period/2;
	clk <= '0';
	wait for period/2;
end process;
-- reset
process
begin
	aclr <= '1';
	wait for period*5;
	aclr <= '0';
	wait;
end process;

-- ram for data
i0100: for i in 0 to cst_RamSectNum-1 generate
	inst01: altsyncram
	generic map(
		numwords_a		=> cst_RamD_Num,
		numwords_b		=> cst_RamD_Num,
		width_a			=> cst_RamSect,--gcst_WD_Mem,
		width_b			=> cst_RamSect,--gcst_WD_Mem,
		widthad_a		=> cst_RamD_Au,
		widthad_b		=> cst_RamD_Au
	)
	port map(
		address_a	=> std_logic_vector(Mem_D_A_Wr(0)(cst_RamD_Au-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
		data_a		=> std_logic_vector(Mem_D_Do(0)((i+1)*cst_RamSect-1 downto i*cst_RamSect)),--:	in std_logic_vector(width_a-1 downto 0);
		wren_a		=> Mem_D_Wr(0),--:	in std_logic;
		
		address_b	=> std_logic_vector(Mem_D_A_Rd(0)(cst_RamD_Au-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
		q_b			=> sgn_Mem_D_Di((i+1)*cst_RamSect-1 downto i*cst_RamSect),--:	out std_logic_vector(width_b-1 downto 0);
		
		clock0		=> clk--:	in std_logic
	);
end generate i0100;
Mem_D_Di(0) <= unsigned(sgn_Mem_D_Di);

--inst01: Lg_DP_Ram_Sc
--generic map(
--	Data_Width	=> 256,--gcst_WD_Mem,--256
--	Data_Num 	=> 3*2**21--cst_RamD_Num
--)
--port map(
--	data	=> Mem_D_Do(0),--: in unsigned((Data_Width-1) downto 0);
--	waddr	=> to_integer(Mem_D_A_Wr(0)),--: in natural range 0 to Data_Num - 1;
--	we		=> Mem_D_Wr(0),--: in std_logic := '1';
--	
--	q		=> Mem_D_Di,--: out unsigned((Data_Width -1) downto 0);
--	raddr	=> to_integer(Mem_D_A_Rd),--: in natural range 0 to Data_Num - 1;
--	
--	clk		=> clk--: in std_logic
--);

-- ram for idx
inst02: altsyncram
generic map(
	numwords_a		=> cst_RamIdx_Num,
	numwords_b		=> cst_RamIdx_Num,
	width_a			=> 32,--gcst_WD_idxCache,
	width_b			=> 32,--gcst_WD_idxCache,
	widthad_a		=> cst_RamIdx_Au,
	widthad_b		=> cst_RamIdx_Au
)
port map(
	address_a	=> std_logic_vector(Mem_Idx_A_Wr(0)(cst_RamIdx_Au-1 downto 0)),--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> std_logic_vector(Mem_Idx_Do(0)),--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> Mem_Idx_Wr(0),--:	in std_logic;
	
	address_b	=> std_logic_vector(Mem_Idx_A_Rd(cst_RamIdx_Au-1 downto 0)),--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Mem_Idx_Di,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);
Mem_Idx_Di <= unsigned(sgn_Mem_Idx_Di);

--inst02: Lg_DP_Ram_Sc
--generic map(
--	Data_Width	=> 32,--gcst_WD_idxCache,--32;
--	Data_Num 	=> 10*(2**21+2**19)--cst_RamIdx_Num
--)
--port map(
--	data	=> Mem_Idx_Do(0),--: in unsigned((Data_Width-1) downto 0);
--	waddr	=> to_integer(Mem_Idx_A_Wr(0)),--: in natural range 0 to Data_Num - 1;
--	we		=> Mem_Idx_Wr(0),--: in std_logic := '1';
--	
--	q		=> Mem_Idx_Di,--: out unsigned((Data_Width -1) downto 0);
--	raddr	=> to_integer(Mem_Idx_A_Rd),--: in natural range 0 to Data_Num - 1;
--	
--	clk		=> clk--: in std_logic
--);

-- read ack
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => 2)--1
port map(di => Mem_D_Rd, do => sgn_Mem_D_RdAck, clk => clk, aclr => aclr);
instPP02: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => 2)--1
port map(di => Fnc_STD2U0(Mem_Idx_Rd), do => sgn_Mem_Idx_RdAck, clk => clk, aclr => aclr);

Mem_D_RdAck <= sgn_Mem_D_RdAck;
Mem_Idx_RdAck <= sgn_Mem_Idx_RdAck(0);

-- main control
process
begin
	for i in 0 to gcst_W_Nounce-1 loop
		Nounce(i) <= to_unsigned(i,gcst_WW);
	end loop;
	St <= '0';
	
	wait for period*400;
	St <= '1';
	wait for period;
	St <= '0';
	
	wait until Ed='1';
	wait for period*100;
	
	wait for period*400;
	St <= '1';
	wait for period;
	St <= '0';
	
	wait;
end process;


END Equihash_PoW_Wrapper_arch;
