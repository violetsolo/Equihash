----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    12/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsStp3 - Behavioral
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

entity Equihash_GBP_CllsStp3 is
generic(
	sBucket_Width	: Natural := 8;
	sBucket_Offset	: Natural := 12;
	sBucket_Num		: Natural := 2**8;
	sBucket_MaxCap	: Natural := 2**5 -- 17
);
port (
	sBucket_Get		: out	std_logic;
	sBucket_GetIdx	: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	sBucket_Cnt		: in	Natural range 0 to sBucket_MaxCap;
	
	sBucket_Init	: out	std_logic;
	sBucket_Rdy		: in	std_logic;
	
	Acc_Clr			: out	std_logic;
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_p			: out	Natural range 0 to sBucket_Num-1 := 0; -- hold during process
	Param_sBn		: out	Natural range 0 to sBucket_MaxCap := 0; -- hold during process
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
	clk				: in	std_logic;
	sclr			: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp3;

architecture rtl of Equihash_GBP_CllsStp3 is
--============================ constant declare ============================--
constant cst_GetW_DL		: Natural := gcst_BucketDisp_RtlDL_Get;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Init, S_InitW, S_GetCnt, S_GetW, S_preProc, S_nxtW, S_Fin);
signal state				: typ_state;

signal sgn_p				: Natural range 0 to sBucket_Num := 0;
signal sgn_GetIdx			: unsigned(gcst_W_Chunk-1 downto 0) := (others => '0');
signal sgn_GetW_Cnt			: Natural range 0 to cst_GetW_DL := 0;

signal sgn_sBn				: Natural range 0 to sBucket_MaxCap := 0;
signal sgn_sBucket_Rdy		: std_logic;
--============================ function declare ============================--

begin

sBucket_GetIdx <= sgn_GetIdx sll sBucket_Offset;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Init;
		sBucket_Get <= '0';
		sBucket_Init <= '0';
		Acc_Clr <= '0';
		Cache_Sel <= '0';
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_p <= 0;
		sgn_sBucket_Rdy <= '1';
	elsif(rising_edge(clk))then
		if(sclr='1')then
			state <= S_Idle;
			sBucket_Get <= '0';
			sBucket_Init <= '0';
			Acc_Clr <= '0';
			Cache_Sel <= '0';
			nxt_St <= '0';
			Ed <= '0';
			Bsy <= '0';
			-- signal
			sgn_p <= 0;
			sgn_sBucket_Rdy <= '1';
		else
			sgn_sBucket_Rdy <= sBucket_Rdy;
			case state is
				when S_Init =>
					sBucket_Init <= '1';
					state <= S_InitW;
				
				when S_InitW =>
					sBucket_Init <= '1';
					if(sgn_sBucket_Rdy = '0' and sBucket_Rdy = '1')then
						Ed <= '1';
						state <= S_Idle;
					end if;
				
				when S_Idle =>
					Ed <= '0';
					if(St = '1')then
						state <= S_GetCnt;
						Cache_Sel <= '1';
						Bsy <= '1';
					else
						Cache_Sel <= '0';
						Bsy <= '0';
					end if;
				
				when S_GetCnt =>
					sBucket_Get <= '1';-- get bucket counter
					sgn_GetIdx <= to_unsigned(sgn_p,sgn_GetIdx'length);-- bucket index is sgn_p
					sgn_GetW_Cnt <= 0; -- reset wait counter
					state <= S_GetW;
				
				when S_GetW =>
					sBucket_Get <= '0';
					sgn_GetW_Cnt <= sgn_GetW_Cnt + 1; -- wait counter increase
					if(sgn_GetW_Cnt >= cst_GetW_DL-1)then-- bucket module delay
						state <= S_preProc;
						sgn_sBn <= sBucket_Cnt;-- save bucket counter
						Param_sBn <= sBucket_Cnt; -- set sBn outter
					end if;
				
				when S_preProc =>
					if(sgn_sBn <= 1)then-- less than 1 element
						state <= S_Fin;
					else
						nxt_St <= '1';-- start next sm
						Param_p <= sgn_p;-- set sgn_p outter
						if(sgn_p = 0)then -- first time
							Acc_Clr <= '1'; -- clear Acc
						else
							Acc_Clr <= '0';
						end if;
						state <= S_nxtW;
					end if;
				
				when S_nxtW =>
					Acc_Clr <= '0';
					nxt_St <= '0';
					if(nxt_Ed='1')then-- wait next sm finish
						state <= S_Fin;
					end if;
				
				when S_Fin =>
					if(sgn_p = sBucket_Num-1)then-- last sub_bucket
						sgn_p <= 0;
						state <= S_Init;
					else
						sgn_p <= sgn_p + 1;-- sub_bucket index (sgn_p) increase
						state <= S_GetCnt;
					end if;
				
				when others => State <= S_Init;
			end case;
		end if;
	end if;
end process;

end rtl;

