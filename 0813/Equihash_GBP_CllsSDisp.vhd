----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    14/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsSDisp - Behavioral
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

entity Equihash_GBP_CllsSDisp is
generic(
	Num_sThread		: Natural := 4
);
port (
	Param_q			: out	Natural range 0 to gcst_mBucket_Num-1;
	mBn				: in	Natural range 0 to gcst_mBucket_MaxCap;
	
	sTh_Valid		: in	unsigned(Num_sThread-1 downto 0);
	sTh_Bsy			: in	unsigned(Num_sThread-1 downto 0);
	Tsk_Push		: out	unsigned(Num_sThread-1 downto 0);
	sTh_Msk			: in	unsigned(Num_sThread-1 downto 0); --'1'valid, '0' invalid
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	TskGen_St		: out	std_logic;
	TskGen_Ed		: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsSDisp;

architecture rtl of Equihash_GBP_CllsSDisp is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_TskGen, S_TskGenW, S_Robin, S_nTsk, S_ThW);
signal state	: typ_state;

signal sgn_q				: Natural range 0 to gcst_mBucket_Num := 0;
signal sgn_sThCnt			: Natural range 0 to Num_sThread-1;
signal sgn_sTh_Valid		: unsigned(Num_sThread-1 downto 0);
--============================ function declare ============================--

begin

-- set/clr thread status
sgn_sTh_Valid <= sTh_Valid and sTh_Msk;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		TskGen_St <= '0';
		Tsk_Push <= (others => '0');
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_q <= 0;
		sgn_sThCnt <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					state <= S_TskGen;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_TskGen =>
				TskGen_St <= '1';
				Param_q <= sgn_q; -- io
				state <= S_TskGenW;
			
			when S_TskGenW =>
				TskGen_St <= '0';
				if(TskGen_Ed = '1')then
					if(mBn<=1)then
						state <= S_nTsk;
					else
						state <= S_Robin;
					end if;
				end if;
			
			when S_Robin =>
				if(sgn_sTh_Valid(sgn_sThCnt) = '1')then -- current thread valid
					for i in 0 to Num_sThread-1 loop-- push task
						if(i = sgn_sThCnt)then
							Tsk_Push(i)<= '1';
						else
							Tsk_Push(i)<= '0';
						end if;
					end loop;
					state <= S_nTsk;
				end if;
				if(sgn_sThCnt = Num_sThread-1)then
					sgn_sThCnt <= 0;
				else
					sgn_sThCnt <= sgn_sThCnt + 1;
				end if;
			
			when S_nTsk =>
				Tsk_Push <= (others => '0');
				if(sgn_q = gcst_mBucket_Num-1)then
					sgn_q <= 0;
					state <= S_ThW;
				else
					sgn_q <= sgn_q + 1;
					state <= S_TskGen;
				end if;
			
			when S_ThW =>
				if(to_integer(sTh_Bsy) = 0)then
					Ed <= '1';
					state <= S_Idle;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

