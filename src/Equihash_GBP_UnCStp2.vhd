----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    19/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UncmpStp2 - Behavioral
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

entity Equihash_GBP_UncmpStp2 is
port (
	Cache_A_Rd			: out	unsigned(gcst_WA_Idx-1 downto 0);
	Cache_AWrGen_Rst	: out	std_logic;
	
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Mem_Addr_r			: out	unsigned(gcst_WA_Mem-1 downto 0);
	Mem_Rd				: out	std_logic;
	Mem_RdBsy			: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_UncmpStp2;

architecture rtl of Equihash_GBP_UncmpStp2 is
--============================ constant declare ============================--
signal cst_IdxCntB_tbl		: typ_1D_Nat(gcst_Round-1 downto 0);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_preRd, S_Rd, S_RdW);
signal state			: typ_state;

signal sgn_rCnt		: Natural range 0 to gcst_Round-1; -- 0~9
signal sgn_rCnt_inv	: Natural range 0 to gcst_Round-1; -- 0~9
signal sgn_mCnt		: Natural range 0 to gcst_Size_Idx; -- 0~512

signal sgn_SelRam		: std_logic;
signal sgn_Mem_RdBsy	: std_logic;
--============================ function declare ============================--

begin
-- initial table
i0100: for i in 0 to gcst_Round-1 generate
	cst_IdxCntB_tbl(i) <= 2**i; -- initialize table
end generate i0100;

-- ram select order
-- 0->Ao:Bi(1), 1->Ai:Bo(0), 2->Ao:Bi(1)..., 9->Ai:bo(0)
Cache_SelRam <= sgn_SelRam; 

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_AWrGen_Rst <= '0';
		Cache_SelCh <= '0';
		Mem_Rd <= '0';
		sgn_SelRam <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_rCnt_inv <= gcst_Round-1;
		sgn_rCnt <= 0;
		sgn_mCnt <= 0;
		sgn_Mem_RdBsy <= '0';
	elsif(rising_edge(clk))then
		sgn_Mem_RdBsy <= Mem_RdBsy;
		case state is
			when S_Idle =>
				Ed <= '0';
				nxt_St <= '0';
				if(St = '1')then
					Cache_SelCh <= '1';
					state <= S_preRd;
					Bsy <= '1';
				else
					Cache_SelCh <= '0';
					Bsy <= '0';
				end if;
			
			when S_preRd =>
				sgn_SelRam <= not sgn_SelRam; -- cross ram A and ram B
				Cache_AWrGen_Rst <= '1'; -- reset cache write address generator
				Mem_Addr_r <= to_unsigned(sgn_rCnt_inv,gcst_WA_Mem); -- set Mem addr r
				state <= S_Rd;
			
			when S_Rd =>
				Cache_AWrGen_Rst <= '0';
				if(sgn_mCnt = cst_IdxCntB_tbl(sgn_rCnt))then-- last value
					sgn_mCnt <= 0; -- cache read addr reset
					Mem_Rd <= '0'; -- read mem disable
					state <= S_RdW;
				else
					Mem_Rd <= '1'; -- read mem enable
					Cache_A_Rd <= to_unsigned(sgn_mCnt,gcst_WA_Idx);
					sgn_mCnt <= sgn_mCnt + 1; -- cache read addr increase
				end if;
			
			when S_RdW =>
				if(Mem_RdBsy = '0' and sgn_Mem_RdBsy = '1')then -- falling edge
					if(sgn_rCnt_inv = 0)then -- last round
						sgn_rCnt_inv <= gcst_Round-1; -- reset round counter
						sgn_rCnt <= 0; -- reset round counter
						sgn_SelRam <= '0'; -- reset cross state
						nxt_St <= '1';
						Ed <= '1';
						state <= S_Idle;
					else
						sgn_rCnt_inv <= sgn_rCnt_inv - 1; -- round counter decrease
						sgn_rCnt <= sgn_rCnt + 1; -- round counter increase
						state <= S_preRd;
					end if;
				end if;
				
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

