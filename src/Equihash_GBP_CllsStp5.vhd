----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    13/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_CllsStp5 - Behavioral
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

entity Equihash_GBP_CllsStp5 is
generic(
	sBucket_MaxCap	: Natural := 2**5 -- 17
);
port (
	Cache_Addr_j	: out	unsigned(gcst_WA_Cache-1 downto 0);
	Cache_Stp		: out	unsigned(gcst_WD_Cache_Stp-1 downto 0);
	
	LastRound		: in	std_logic;
	
	mC_Latch		: out	std_logic;
	
	Mem_Wr			: out	std_logic;
	Mem_Addr_j		: out	unsigned(gcst_WA_Mem-1 downto 0);
	
	mBucket_Inc		: out	std_logic;
	
	IdxReqNum		: out	Natural;
	IdxReq			: out	std_logic;
	IdxAckVal		: in	Natural;
	IdxAck			: in	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to sBucket_MaxCap;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp5;

architecture rtl of Equihash_GBP_CllsStp5 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_GetCnt, S_RdmC, S_RdsC, S_IdxReq, S_IdxReqW);
signal state	: typ_state;

signal sgn_j		: Natural range 0 to sBucket_MaxCap := 0;
signal sgn_k		: Natural range 0 to sBucket_MaxCap := 0;

signal sgn_Acc	: Natural range 0 to 2**gcst_WD_Cache_Idx-1 := 0; -- 2^24 (3*2^21 actually)
--============================ function declare ============================--

begin

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		mC_Latch <= '0';
		mBucket_Inc <= '0';
		Mem_Wr <= '0';
		IdxReq <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_j <= 0;
		sgn_k <= 0;
		sgn_Acc <= 0;
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				mBucket_Inc <= '0';
				Mem_Wr <= '0';
				Ed <= '0';
				if(St = '1')then
					Bsy <= '1';
					if(LastRound='0')then -- not last round
						state <= S_RdmC;
					else
						state <= S_IdxReq;
					end if;
				else
					Bsy <= '0';
				end if;
			
			when S_IdxReq =>
				IdxReq <= '1';
				IdxReqNum <= Param_sBn-1-sgn_j;
				state <= S_IdxReqW;
			
			when S_IdxReqW =>
				-- hold IdxReq until ack arrive
				if(IdxAck = '1')then
					IdxReq <= '0';
					sgn_Acc <= IdxAckVal;
					state <= S_RdmC;
				end if;
			
			when S_RdmC => 
				mBucket_Inc <= '0';
				Mem_Wr <= '0';
				Cache_Addr_j <= to_unsigned(sgn_j, Cache_Addr_j'length); -- set sgn_j outter
				sgn_k <= sgn_j+1; -- initial sgn_k
				mC_Latch <= '1'; -- latch main collision value
				state <= S_RdsC;
				
			when S_RdsC =>
				mC_Latch <= '0';
				Cache_Addr_j <= to_unsigned(sgn_k, Cache_Addr_j'length); -- set sgn_k outter
				Cache_Stp <= to_unsigned(sgn_k - sgn_j, Cache_Stp'length); -- calculate step
				if(LastRound='1')then -- last round 
					Mem_Addr_j <= to_unsigned(sgn_Acc,Mem_Addr_j'length);
					sgn_Acc <= sgn_Acc + 1; -- Acc increase
					Mem_Wr <= '1'; -- wr mem
				else
					mBucket_Inc <= '1'; -- trig bucket
				end if;
				
				if(sgn_k = Param_sBn-1)then
					if(sgn_j = Param_sBn-2)then -- finish
						sgn_j <= 0;
						Ed <= '1';
						state <= S_Idle;
					else
						sgn_j <= sgn_j + 1; -- sgn_j increase
						if(LastRound='0')then -- not last round
							state <= S_RdmC;
						else
							state <= S_IdxReq;
						end if;
					end if;
				else
					sgn_k <= sgn_k + 1; -- sgn_k increase
					state <= S_RdsC;
				end if;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

