----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    19/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UncmpStp1 - Behavioral
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

entity Equihash_GBP_UncmpStp1 is
port (
	Num_Idx				: in	Natural; -- must be hold outter
	
	Cache_A_Wr			: out	unsigned(gcst_WA_Idx-1 downto 0);
	Cache_Di			: out	unsigned(gcst_WD_Idx-1 downto 0);
	Cache_Wr			: out	std_logic;
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	nxt_Ed				: in	std_logic;
	nxt_abort			: in	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_UncmpStp1;

architecture rtl of Equihash_GBP_UncmpStp1 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Wr, S_St, S_Wait);
signal state			: typ_state;

signal sgn_nCnt	: Natural;
--============================ function declare ============================--

begin

Cache_SelRam <= '0'; -- Ai:Bo(0)
Cache_A_Wr <= (others => '0');

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_SelCh <= '0';
		Cache_Wr <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_nCnt <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					state <= S_Wr;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_Wr =>
				Cache_SelCh <= '1';
				Cache_Wr <= '1'; -- write first idx address into cache
				Cache_Di <= to_unsigned(sgn_nCnt,gcst_WD_Idx);
				state <= S_St;
			
			when S_St =>
				Cache_Wr <= '0';
				Cache_SelCh <= '0';
				nxt_St <= '1';
				state <= S_Wait;
			
			when S_Wait =>
				nxt_St <= '0';
				if(nxt_abort='1' or nxt_Ed='1')then -- current turn abort or finish
					if(sgn_nCnt = Num_Idx-1)then -- last idx value
						sgn_nCnt <= 0; -- reset counter
						Ed <= '1';
						state <= S_Idle;
					else
						sgn_nCnt <= sgn_nCnt + 1; -- value counter increase
						state <= S_Wr;
					end if;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

