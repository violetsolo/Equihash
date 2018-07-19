----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    19/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UncmpStp4 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
--for (r=0; r<9; r++)
--	for (i=0; i<2^(8-r); i++)
--		if (a(2*i*2^r) > a((2*i+1)*2^r))
--			for (j=2*i*2^r, k=a((2*i+1)*2^r), t=0; j<2^r; j++,k++,t++)
--				a(j) <> a(k)
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

entity Equihash_GBP_UncmpStp4 is
port (
	Cache_SelCh			: out	std_logic;
	Cache_SelRam		: out	std_logic; -- '1' Ram A output and Ram B input; '0' Ram A input and Ram B output
	
	Cache_A_Rd			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_A_Wr			: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr			: out	std_logic;
	
	CmpRes				: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	nxt_St				: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_GBP_UncmpStp4;

architecture rtl of Equihash_GBP_UncmpStp4 is
--============================ constant declare ============================--
signal cst_IdxCntB_tbl		: typ_1D_Nat(gcst_Round-1 downto 0); -- 0~8
signal cst_IdxCntR_tbl		: typ_1D_Nat(gcst_Round-1 downto 0);
constant cst_RamRdDL		: Natural := gcst_IdxCache_RtlDL_Rd;
-- sub next data read lag (ram delay(4) + read slave data(1) + compare(1) - read master data(1))
constant cst_CmpResDL		: Natural := cst_RamRdDL + 1 + 1 - 1; 

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_preSet, 
					S_mRd, S_sRd, S_RdW,
					S_mCpy, S_sCpy, 
					S_mCross, S_sCross, 
					S_TransW,
					S_Fin);
signal state			: typ_state;
signal state_aux		: typ_state;

signal sgn_rCnt		: Natural range 0 to gcst_Round-1; --0~8
signal sgn_mCnt		: Natural;
signal sgn_sCnt		: Natural;

signal sgn_tCnt		: Natural;
signal sgn_srCnt	: Natural;

signal sgn_wCnt		: Natural;
signal sgn_IdxCntB	: Natural;
signal sgn_IdxCntR	: Natural;

signal sgn_SelRam	: std_logic;
--============================ function declare ============================--

begin
i0100: for i in 0 to gcst_Round-1 generate -- 0~8
	cst_IdxCntB_tbl(i) <= 2**i; -- initialize table 1 2 4 ... 256
	cst_IdxCntR_tbl(i) <= 2**(gcst_Round-1-i); -- 256 128 64 ... 1
end generate i0100;

-- ram select order
-- 0->Ao:Bi(1), 1->Ai:Bo(0), 2->Ao:Bi(1)..., 8->Ao:Bi(1)
Cache_SelRam <= sgn_SelRam;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		state_aux <= S_Idle;
		Cache_SelCh <='0';
		Cache_Wr <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_SelRam <= '0';
		sgn_rCnt <= 0;
		sgn_mCnt <= 0;
		sgn_sCnt <= 0;
		sgn_wCnt <= 0;
		sgn_tCnt <= 0;
		sgn_srCnt <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				nxt_St <= '0';
				sgn_SelRam <= '0'; -- set default
				if(St = '1')then
					Cache_SelCh <= '1'; -- get cache control right
					state <= S_preSet;
					Bsy <= '1';
				else
					Cache_SelCh <= '0'; -- release cache control right
					Bsy <= '0';
				end if;
			
			when S_preSet => -- set inital value
				sgn_SelRam <= not sgn_SelRam; -- inverse cache ram
				sgn_mCnt <= 0; -- set m counter initial value
				sgn_sCnt <= cst_IdxCntB_tbl(sgn_rCnt); -- set s counter initial value
				sgn_IdxCntB <= cst_IdxCntB_tbl(sgn_rCnt); -- get counter bound in current turn
				sgn_IdxCntR <= cst_IdxCntR_tbl(sgn_rCnt); -- get process round in current turn
				state <= S_mRd;
			
			when S_mRd => -- read first comp data
				Cache_A_Rd <= to_unsigned(sgn_mCnt, gcst_WA_idxCache);
				state <= S_sRd; 
				
			when S_sRd => -- read second comp data
				Cache_A_Rd <= to_unsigned(sgn_sCnt, gcst_WA_idxCache);
				state <= S_RdW;
			
			when S_RdW =>
				sgn_wCnt <= sgn_wCnt + 1;
				if(sgn_wCnt = cst_CmpResDL)then -- wait for compare result generate
					if(CmpRes = '0') then -- a < b hold data order
						state <= S_mCpy;
					else -- exchange data order
						state <= S_mCross;
					end if;
					sgn_wCnt <= 0;
				end if;
				
			when S_mCpy =>
				Cache_A_Rd <= to_unsigned(sgn_mCnt, gcst_WA_idxCache); -- read first date
				Cache_A_Wr <= to_unsigned(sgn_mCnt, gcst_WA_idxCache); -- write first data
				Cache_Wr <= '1';
				state <= S_sCpy;
				
			when S_sCpy =>
				sgn_mCnt <= sgn_mCnt + 1; -- m counter increase
				sgn_sCnt <= sgn_sCnt + 1; -- s counter increase
				Cache_A_Rd <= to_unsigned(sgn_sCnt, gcst_WA_idxCache); -- read second data
				Cache_A_Wr <= to_unsigned(sgn_sCnt, gcst_WA_idxCache); -- write second data
				Cache_Wr <= '1';
				
				if(sgn_tCnt = sgn_IdxCntB-1)then -- last data in date seq
					sgn_tCnt <= 0;
					state <= S_Fin;
				else
					sgn_tCnt <= sgn_tCnt + 1; -- read data number increase
					state <= S_mCpy;
				end if;
				
			when S_mCross =>
				Cache_A_Rd <= to_unsigned(sgn_mCnt, gcst_WA_idxCache); -- read first date
				Cache_A_Wr <= to_unsigned(sgn_sCnt, gcst_WA_idxCache); -- write first data
				Cache_Wr <= '1';
				state <= S_sCross;
				
			when S_sCross =>
				sgn_mCnt <= sgn_mCnt + 1; -- m counter increase
				sgn_sCnt <= sgn_sCnt + 1; -- s counter increase
				Cache_A_Rd <= to_unsigned(sgn_sCnt, gcst_WA_idxCache); -- read second data
				Cache_A_Wr <= to_unsigned(sgn_mCnt, gcst_WA_idxCache); -- write second data
				Cache_Wr <= '1';
				
				if(sgn_tCnt = sgn_IdxCntB-1)then -- last data in date seq
					sgn_tCnt <= 0;
					state <= S_Fin;
				else
					sgn_tCnt <= sgn_tCnt + 1; -- read data number increase
					state <= S_mCross;
				end if;
				
			when S_Fin =>
				Cache_Wr <= '0';
				if(sgn_srCnt = sgn_IdxCntR - 1)then -- last round of current turn
					sgn_srCnt <= 0;
					if(sgn_rCnt = gcst_Round-1)then -- last round
						sgn_rCnt <= 0;
						state_aux <= S_Idle;
					else
						sgn_rCnt <= sgn_rCnt + 1; -- round counter increase
						state_aux <= S_preSet; -- start next round
					end if;
					state <= S_TransW;
				else
					sgn_srCnt <= sgn_srCnt + 1; -- round counter of current turn increase
					sgn_mCnt <= sgn_mCnt + sgn_IdxCntB; -- m counter modify
					sgn_sCnt <= sgn_sCnt + sgn_IdxCntB; -- s counter modify
					state <= S_mRd; -- restart read and compare process
				end if;
				
			when S_TransW =>
				sgn_wCnt <= sgn_wCnt + 1;
				if(sgn_wCnt = cst_RamRdDL)then -- wait for last data write to ram
					sgn_wCnt <= 0;
					state <= state_aux;
					if(state_aux = S_Idle)then
						nxt_St <= '1'; -- trig next stage work
						Ed <= '1'; -- end 
					end if;
				end if;
				
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

