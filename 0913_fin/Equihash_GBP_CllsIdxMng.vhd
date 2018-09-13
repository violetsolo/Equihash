----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    26/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsIdxMng - Behavioral
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

entity Equihash_GBP_CllsIdxMng is
generic(
	Num_Ch		: Natural := 10
);
port (
	ReqNum	: in	typ_1D_Nat(Num_Ch-1 downto 0);
	Req		: in	unsigned(Num_Ch-1 downto 0);
	
	AckVal	: out	Natural;
	Ack		: out	unsigned(Num_Ch-1 downto 0);
	
	TotNum	: out	Natural;
	Rst		: in	std_logic;
	
	clk		: in	std_logic;
	aclr	: in	std_logic
);
end Equihash_GBP_CllsIdxMng;

architecture rtl of Equihash_GBP_CllsIdxMng is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_cnt		: Natural;
signal sgn_pp		: Natural range 0 to Num_Ch-1;

signal sgn_req		: unsigned(Num_Ch-1 downto 0);
signal sgn_st		: unsigned(Num_Ch-1 downto 0);
--============================ function declare ============================--

begin

TotNum <= sgn_cnt;

process(clk,aclr)
begin
	if(aclr='1')then
		Ack <= (others => '0');
		sgn_cnt <= 0;
		sgn_pp <= 0;
		sgn_req <= (others => '1');
		sgn_st <= (others => '0');
		AckVal <= 0;
	elsif(rising_edge(clk))then
		-- get request and set state
		sgn_req <= req;
		for i in 0 to Num_Ch-1 loop
			if(sgn_req(i)='0' and Req(i)='1')then-- rising edge
				sgn_st(i) <= '1';
			end if;
		end loop;
		-- reset cnt
		if(Rst = '1')then
			sgn_cnt <= 0;
		end if;
		-- robin
		if(sgn_pp = Num_Ch-1)then
			sgn_pp <= 0;
		else
			sgn_pp <= sgn_pp + 1;
		end if;
		-- generate ack accroding to request
		if(sgn_st(sgn_pp) = '1')then
			AckVal <= sgn_cnt; -- 
			sgn_cnt <= sgn_cnt + ReqNum(sgn_pp); -- acc
			sgn_st(sgn_pp) <= '0'; -- clear state
			for i in 0 to Num_Ch-1 loop
				if(i=sgn_pp)then -- 
					Ack(i) <= '1'; -- set current ack
				else
					Ack(i) <= '0'; -- clear others ack
				end if;
			end loop;
		else
			Ack <= (others => '0');
		end if;
	end if;
end process;

end rtl;
