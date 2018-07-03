----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    26/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_IdxMng - Behavioral
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

entity Equihash_GBP_IdxMng is
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
end Equihash_GBP_IdxMng;

architecture rtl of Equihash_GBP_IdxMng is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_cnt		: Natural;
signal sgn_pp		: Natural range 0 to Num_Ch-1;
--============================ function declare ============================--

begin

TotNum <= sgn_cnt;

process(clk,aclr)
begin
	if(aclr='1')then
		Ack <= (others => '0');
		sgn_cnt <= 0;
		sgn_pp <= 0;
	elsif(rising_edge(clk))then
		if(Rst = '1')then
			sgn_cnt <= 0;
		end if;
		if(sgn_pp = Num_Ch-1)then
			sgn_pp <= 0;
		else
			sgn_pp <= sgn_pp + 1;
		end if;
		if(Req(sgn_pp) = '1')then
			sgn_cnt <= sgn_cnt + ReqNum(sgn_pp);
			AckVal <= sgn_cnt;
			for i in 0 to Num_Ch-1 loop
				if(i=sgn_pp)then
					Ack(sgn_pp) <= '1';
				else
					Ack(sgn_pp) <= '0';
				end if;
			end loop;
		else
			Ack <= (others => '0');
		end if;
	end if;
end process;

end rtl;
