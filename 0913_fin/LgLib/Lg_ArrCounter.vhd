----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    27/07/2018 
-- Design Name: 
-- Module Name:    Lg_ArrCounter - Behavioral
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

entity Lg_ArrCounter is
generic(
	Num_Cnt			: Natural := 64;
	Max_Cnt			: Natural := 17
);
port (
	Inc			: in	std_logic;
	Init		: in	std_logic;
	
	Idx_Cnt		: in	Natural range 0 to Num_Cnt-1;
	Cnt_o		: out	Natural range 0 to Max_Cnt;
	
	Rdy			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Lg_ArrCounter;

architecture rtl of Lg_ArrCounter is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Lg_Dsp_nL1b_T1
generic(
	Num				: Positive := Num_Cnt;
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	std_logic;
	Do			: out	unsigned(Num-1 downto 0);
	Sel			: in	Natural;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_SingalPipe
generic(
	Width_D			: Positive;
	Num_Pipe		: Positive
);
port (
	di		: in	unsigned(Width_D-1 downto 0);
	do		: out	unsigned(Width_D-1 downto 0);
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;

component Lg_SingalPipe_Nat
generic(
	Num_Pipe		: Positive
);
port (
	di		: in	Natural;
	do		: out	Natural;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Cnt		: typ_1D_Nat(Num_Cnt-1 downto 0);
signal sgn_Inc_i	: std_logic;
signal sgn_Inc		: unsigned(Num_Cnt-1 downto 0);
signal sgn_Inc_DL	: unsigned(Num_Cnt-1 downto 0);
signal sgn_Pos		: Natural;
signal sgn_MuxSel	: Natural;
signal sgn_Cnt_o	: Natural;
--============================ function declare ============================--

begin

Rdy <= not Init;

i0100: for i in 0 to Num_Cnt-1 generate
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_Cnt(i) <= 0;
		elsif(rising_edge(clk))then
			if(Init='1')then
				sgn_Cnt(i) <= 0;
			elsif(sgn_Inc_DL(i)='1' and sgn_Cnt(i)<Max_Cnt)then
				sgn_Cnt(i) <= sgn_Cnt(i) + 1;
			end if;
		end if;
	end process;
end generate i0100;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Inc_i <= '0';
	elsif(rising_edge(clk))then
		sgn_Inc_i <= Inc;
	end if;
end process;

process(clk,aclr)
begin
	if(rising_edge(clk))then
		sgn_Pos <= Idx_Cnt;
	end if;
end process;

inst01: Lg_Dsp_nL1b_T1
port map(
	Di			=> sgn_Inc_i,--(io): in	std_logic;
	Do			=> sgn_Inc,--: out	unsigned(Num-1 downto 0);
	Sel			=> sgn_Pos,--: in	Natural;
	
	clk			=> '0',--: in	std_logic;
	aclr		=> '0'--: in	std_logic
);

process(clk)
begin
	if(rising_edge(clk))then
		sgn_Cnt_o <= sgn_Cnt(sgn_MuxSel);
	end if;
end process;

Cnt_o <= sgn_Cnt_o;

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => Num_Cnt, Num_Pipe => 1) -- 1
port map(di => sgn_Inc, do => sgn_Inc_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe_Nat
generic map(Num_Pipe => 2) -- 1
port map(di => sgn_Pos, do => sgn_MuxSel, clk => clk, aclr => '0');

end rtl;
