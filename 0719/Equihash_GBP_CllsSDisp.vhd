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
	Param_q			: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	sThread_Sel		: out Natural range 0 to Num_sThread-1;
	sThread_Ed		: in	unsigned(Num_sThread-1 downto 0);
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	nxt_St			: out	std_logic;
	nxt_Ed			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsSDisp;

architecture rtl of Equihash_GBP_CllsSDisp is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Robin, S_nxtW, S_FinW);
signal state	: typ_state;

signal sgn_q				: Natural range 0 to gcst_mBucket_Num := 0;
signal sgn_sThSt			: unsigned(Num_sThread-1 downto 0);
signal sgn_sThSet			: unsigned(Num_sThread-1 downto 0);
signal sgn_sThCnt			: Natural range 0 to Num_sThread-1;
--============================ function declare ============================--

begin

-- set/clr thread status
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_sThSt <= to_unsigned(0,sgn_sThSt'length);
	elsif(rising_edge(clk))then
		for i in 0 to Num_sThread-1 loop
			if(sgn_sThSet(i) = '1')then
				sgn_sThSt(i) <= '1';
			elsif(sThread_Ed(i) = '1')then
				sgn_sThSt(i) <= '0';
			end if;
		end loop;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		nxt_St <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_q <= 0;
		sgn_sThCnt <= 0;
		sgn_sThSet <= (others => '0');
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					state <= S_Robin;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_Robin =>
				if(sgn_sThSt(sgn_sThCnt) = '1')then -- current thread busy
					if(sgn_sThCnt = Num_sThread-1)then -- to next thread status
						sgn_sThCnt <= 0; -- round
					else
						sgn_sThCnt <= sgn_sThCnt + 1; -- increase
					end if;
					state <= S_Robin;
				else -- current thread idle
					sThread_Sel <= sgn_sThCnt; -- set thread selection
					Param_q <= to_unsigned(sgn_q, gcst_WA_Mem); -- io
					nxt_St <= '1';-- start stp 2
					sgn_sThSet(sgn_sThCnt) <= '1'; -- set thread status
					state <= S_nxtW;
				end if;
			
			when S_nxtW => -- wait for thread begin (stp2 finish)
				nxt_St <= '0';
				sgn_sThSet <= (others => '0'); -- clear set signal
				if(nxt_Ed='1')then
					if(sgn_q = gcst_mBucket_Num-1)then -- last bucket is in process
--					if(sgn_q = 100-1)then -- (only for test)last bucket is in process
						sgn_q <= 0; -- reset sgn_q
						state <= S_FinW;
					else
						sgn_q <= sgn_q + 1; -- point to next bucket
						if(sgn_sThCnt = Num_sThread-1)then -- point to next thread
							sgn_sThCnt <= 0; -- round
						else
							sgn_sThCnt <= sgn_sThCnt + 1; -- increase
						end if;
						state <= S_Robin;
					end if;
				end if;
			
			when S_FinW =>
				if(to_integer(sgn_sThSt) = 0)then -- all thread finish
					Ed <= '1';
					state <= S_Idle;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

