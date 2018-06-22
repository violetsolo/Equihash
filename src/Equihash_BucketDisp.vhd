----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/06/2018 
-- Design Name: 
-- Module Name:    Equihash_BucketDisp - Behavioral
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

entity Equihash_BucketDisp is
generic(
	Device_Family	: string := "Cyclone V";
	Width_Addr		: Natural := 32;
	Bucket_Width	: Natural := 12;
	Bucket_Offset	: Natural := 0;
	Bucket_Num		: Natural := 2**12;
	Bucket_MaxCap	: Natural := 2**11 -- 3*2**9
);
port (
	AB_Bucket	: in	unsigned(Width_Addr-1 downto 0);
	AB_Buff		: in	unsigned(Width_Addr-1 downto 0);

	D_i			: in	unsigned(gcst_WD_Mem-1 downto 0);
	ChunkSel	: in	Natural range 0 to gcst_N_Chunk-1;
	Inc			: in	std_logic;
			
	Mem_D		: out	unsigned(gcst_WD_Mem-1 downto 0);
	Mem_A		: out	unsigned(Width_Addr-1 downto 0);
	Mem_Wr		: out	std_logic;
	
	Get			: in	std_logic;
	GetIdx		: in	unsigned(gcst_W_Chunk-1 downto 0); -- heed: value locate at Bucket_Offset+Fnc_Int2Wd(Bucket_Num-1)-1 downto Bucket_Offset
	Cnt_o		: out	Natural range 0 to Bucket_MaxCap;
	
	Init		: in	std_logic;
	Rdy			: out	std_logic;
	
	clk			: in	std_logic;
	sclr		: in	std_logic := '0';
	aclr		: in	std_logic := '0'
);
end Equihash_BucketDisp;

architecture rtl of Equihash_BucketDisp is
--============================ constant declare ============================--
constant cst_Width_Counter	: Natural := Fnc_Int2Wd(Bucket_MaxCap);
constant cst_Expo_NumCnt	: Natural := Fnc_Int2Wd(Bucket_Num-1);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Lg_RamCounter
generic(
	Device_Family	: string := Device_Family;
	Num_Cnt			: Natural := Bucket_Num;
	Max_Cnt			: Natural := Bucket_MaxCap
);
port (
	Inc			: in	std_logic;
	Init		: in	std_logic;
	
	Idx_Cnt		: in	unsigned(Fnc_Int2Wd(Num_Cnt-1)-1 downto 0);
	Cnt_o		: out	unsigned(Fnc_Int2Wd(Max_Cnt)-1 downto 0);
	
	Rdy			: out	std_logic;
	
	clk			: in	std_logic;
	sclr		: in	std_logic := '0';
	aclr		: in	std_logic := '0'
);
end component;
--============================= signal declare =============================--
type typ_DiMux is array (natural range<>) of unsigned(gcst_W_Chunk-1 downto 0);
signal sgn_DiMux_i		: typ_DiMux(gcst_N_Chunk-1 downto 0);
signal sgn_DiMux_o		: unsigned(gcst_W_Chunk-1 downto 0);

signal sgn_BucketCnt	: unsigned(cst_Width_Counter-1 downto 0);
signal sgn_AddrBucket	: unsigned(Width_Addr-1 downto 0);
signal sgn_AddrBuff		: unsigned(Width_Addr-1 downto 0);

signal sgn_Get			: std_logic;
signal sgn_GetIdx		: unsigned(gcst_W_Chunk-1 downto 0);

constant cst_Di_DL		: Natural := gcst_LgRamCounter_RtlDL + 1 + 1;
type typ_Di_DL is array (cst_Di_DL-1 downto 0) of unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_Di			: unsigned(gcst_WD_Mem-1 downto 0);
signal sgn_Di_DL		: typ_Di_DL;
constant cst_Inc_DL		: Natural := gcst_LgRamCounter_RtlDL + 1 + 1;
signal sgn_Inc			: std_logic;
signal sgn_Inc_DL		: unsigned(cst_Inc_DL-1 downto 0);
signal sgn_DiMuxO_DL	: unsigned(gcst_W_Chunk-1 downto 0);
--============================ function declare ============================--

begin

-- input data mux
i0100: for i in 0 to gcst_N_Chunk-1 generate
	sgn_DiMux_i(i) <= sgn_Di((i+1)*gcst_W_Chunk-1 downto i*gcst_W_Chunk);
end generate;

sgn_Get <= Get;
sgn_GetIdx <= GetIdx;
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_Get='1')then
			sgn_DiMux_o <= sgn_GetIdx;
		else
			sgn_DiMux_o <= sgn_DiMux_i(ChunkSel);
		end if;
	end if;
end process;

-- counter
inst01: Lg_RamCounter
port map(
	Inc			=> sgn_Inc_DL(0),--: in	std_logic;
	Init		=> Init,--: in	std_logic;
	
	Idx_Cnt		=> sgn_DiMux_o(Bucket_Offset+cst_Expo_NumCnt-1 downto Bucket_Offset),--: in	unsigned(Fnc_Int2Wd(Num_Cnt-1)-1 downto 0);
	Cnt_o		=> sgn_BucketCnt,--: out	unsigned(Fnc_Int2Wd(Max_Cnt)-1 downto 0);
	
	Rdy			=> Rdy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	sclr		=> sclr,--: in	std_logic := '0';
	aclr		=> aclr--: in	std_logic := '0'
);

-- multiply and add
process(clk)
begin
	if(rising_edge(clk))then
		sgn_AddrBucket <= sgn_DiMuxO_DL(Bucket_Offset+Bucket_Width-1 downto Bucket_Offset) * 
						  AB_Bucket(Width_Addr-Bucket_Width-1 downto 0);
		sgn_AddrBuff <= sgn_AddrBucket + sgn_BucketCnt + AB_Buff;
	end if;
end process;

-- outout
Cnt_o	<= to_integer(sgn_BucketCnt);
Mem_D	<= sgn_Di_DL(cst_Di_DL-1);
Mem_A	<= sgn_AddrBuff;
Mem_Wr	<= sgn_Inc_DL(cst_Inc_DL-1);

-- delay
sgn_Di <= D_i;
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Di_DL(0) <= sgn_Di;
		for i in 1 to cst_Di_DL-1 loop
			sgn_Di_DL(i) <= sgn_Di_DL(i-1);
		end loop;
		sgn_DiMuxO_DL <= sgn_DiMux_o;
	end if;
end process;

sgn_Inc <= Inc;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Inc_DL <= to_unsigned(0,sgn_Inc_DL'length);
	elsif(rising_edge(clk))then
		if(sclr='1')then
			sgn_Inc_DL <= to_unsigned(0,sgn_Inc_DL'length);
		else
			sgn_Inc_DL(0) <= sgn_Inc;
			for i in 1 to cst_Inc_DL-1 loop
				sgn_Inc_DL(i) <= sgn_Inc_DL(i-1);
			end loop;
		end if;
	end if;
end process;

end rtl;

