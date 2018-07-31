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
	Cache_A_Wr			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Di			: out	unsigned(gcst_WD_idxCache-1 downto 0); -- 32bit
	Cache_Wr			: out	std_logic;
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	InfoLst_AB			: in	unsigned(gcst_WD_idxCache-1 downto 0);
	InfoLst_Num			: in	Natural;
	InfoLst_Rd			: out	std_logic;
	InfoLst_Emp			: in	std_logic;
	
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
type typ_state is (S_Idle, S_GetW, S_Info, S_Wr, S_Nxt, S_Wait);
signal state			: typ_state;

signal sgn_nCnt			: Natural;
signal sgn_nTot			: Natural;
--============================ function declare ============================--

begin

Cache_SelRam <= '0'; -- Ai:Bo(0)
Cache_A_Wr <= (others => '0');
Cache_Di <= to_unsigned(sgn_nCnt,gcst_WD_idxCache);

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_SelCh <= '0';
		Cache_Wr <= '0';
		InfoLst_Rd <= '0';
		nxt_St <= '0';
		Bsy <= '0';
		-- signal
		sgn_nCnt <= 0;
		sgn_nTot <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				if(InfoLst_Emp='0')then
					state <= S_GetW;
					InfoLst_Rd <= '1';
					Bsy <= '1';
				else
					state <= S_Idle;
					Bsy <= '0';
				end if;
			
			when S_GetW => -- wait 1clk
				InfoLst_Rd <= '0';
				state <= S_Info;
			
			when S_Info =>
				sgn_nTot <= InfoLst_Num;
				sgn_nCnt <= to_integer(InfoLst_AB);
				state <= S_Wr;
			
			when S_Wr =>
				Cache_SelCh <= '1';
				Cache_Wr <= '1'; -- write first idx address into cache
				state <= S_Nxt;
			
			when S_Nxt =>
				Cache_Wr <= '0';
				Cache_SelCh <= '0';
				nxt_St <= '1';
				state <= S_Wait;
			
			when S_Wait =>
				nxt_St <= '0';
				if(nxt_abort='1' or nxt_Ed='1')then -- current turn abort or finish
					if(sgn_nTot = 1)then -- last idx value
						state <= S_Idle;
					else
						sgn_nTot <= sgn_nTot - 1;
						sgn_nCnt <= sgn_nCnt + 1; -- value counter increase
						state <= S_Wr;
					end if;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

