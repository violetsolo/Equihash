----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/07/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_ClsStp4 - Behavioral
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

entity Equihash_GBP_CllsStp4 is
port (
	LastRound		: in	std_logic;
	
	Param_jk		: out	Natural;
	
	Mem_Wr			: out	std_logic; 
	Mem_Wr_Lst		: out	std_logic; -- last info_num inc en
	Mem_Sel			: out	std_logic;
	Mem_Valid		: in	std_logic;
	
	mBucket_Inc		: out	std_logic;
	mBucket_Valid	: in	std_logic;
	
	mC_Latch		: out	std_logic;
	Acc_Inc			: out	std_logic;
	
	Buff_P_Rd		: out	std_logic;
	Buff_P_Emp		: in	std_logic;
	
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Param_sBn		: in	Natural range 0 to gcst_sBucket_MaxCap;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp4;

architecture rtl of Equihash_GBP_CllsStp4 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_W, S_Stp5, S_Stp4_Lst, S_Stp5_Lst);
signal state		: typ_state;

signal sgn_j		: Natural range 0 to gcst_sBucket_MaxCap+1;
signal sgn_k		: Natural range 0 to gcst_sBucket_MaxCap+1;

signal sgn_Wr		: std_logic;
signal sgn_Wr_Lst	: std_logic;
--============================ function declare ============================--

begin

Mem_Wr <= sgn_Wr or sgn_Wr_Lst;
Mem_Wr_Lst <= sgn_Wr_Lst;

process(clk,aclr)
begin
	if(aclr='1')then
		state <= S_Idle;
		Buff_P_Rd <= '0';
		mC_Latch <= '0';
		Mem_Sel <= '0';
		mBucket_Inc <= '0';
		Acc_Inc <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_j <= 0;
		sgn_k <= 0;
		sgn_Wr <= '0';
		sgn_Wr_Lst <= '0';
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Ed <= '0';
				sgn_j <= 0;
				mC_Latch <= '0';
				Acc_Inc <= '0';
				sgn_Wr <= '0';
				sgn_Wr_Lst <= '0';
				mBucket_Inc <= '0';
				if(Buff_P_Emp='0')then -- at least 1 task in fifo
					Buff_P_Rd <= '1'; -- get new task
					Bsy <= '1';
					if(LastRound='1')then
						state <= S_Stp4_Lst;
					else
						state <= S_W;
					end if;
				else
					Bsy <= '0';
				end if;
			
			when S_W => -- wait 1clk
--				sgn_Wr_Lst <= '0'; -- no last round wr operation
				Buff_P_Rd <= '0';
				Ed <= '0';
				Acc_Inc <= '0';
				mBucket_Inc <= '0';
				Param_jk <= sgn_j;
				sgn_k <= 1;
				if(Mem_Valid='1')then
					mC_Latch <= '1';
					sgn_Wr <= '1';
					if(LastRound='1')then
						state <= S_Stp5_Lst;
					else
						state <= S_Stp5;
					end if;
				else
					mC_Latch <= '0';
					sgn_Wr <= '0';
				end if;
			
			when S_Stp5 =>
--				sgn_Wr_Lst <= '0'; -- no last round wr operation
				Param_jk <= Param_sBn - sgn_k;-- get data and gen new idx
				
				if(Mem_Valid='1' and mBucket_Valid='1')then
					if(sgn_k = Param_sBn-1-sgn_j)then -- last k
						sgn_j <= sgn_j + 1;
						if(sgn_j = Param_sBn-2)then -- last j
							Acc_Inc <= '1'; -- acc increase
							Ed <= '1'; -- current round finish
							if(Buff_P_Emp='0')then -- there is at lest 1 task
								state <= S_W;
								sgn_j <= 0; -- reset j
								Buff_P_Rd <= '1'; -- get new task
							else
								state <= S_Idle; -- no task and go back idle
							end if;
						else
							sgn_k <= 1; -- reset k
						end if;
					else
						sgn_k <= sgn_k + 1; -- k increase
					end if;
					
					if(sgn_k = Param_sBn-1-sgn_j)then -- lase k
						mC_Latch <= '1'; -- latch last value = first value of next round
						sgn_Wr <= '1'; -- write old index of last value = first value of next round
					else
						mC_Latch <= '0';
						sgn_Wr <= '0';
					end if;
					
					mBucket_Inc <= '1'; -- mBucket work induction
					Mem_Sel <= '0';
				else
					Ed <= '0';
					Acc_Inc <= '0';
					mC_Latch <= '0';
					sgn_Wr <= '0';
					mBucket_Inc <= '0';
					Buff_P_Rd <= '0';
				end if;
				
			when S_Stp4_Lst =>
--				mBucket_Inc <= '0'; -- no mbucket operation
				Mem_Sel <= '0';
				Param_jk <= sgn_j; -- get data, old index and gen new idx
				sgn_Wr_Lst <= '0';
				
				if(Mem_Valid='1')then
					mC_Latch <= '1'; -- latch data and new index
					sgn_Wr <= '1'; -- write old index to ram
					if(sgn_j=Param_sBn-1)then -- last j
						Ed <= '1'; -- current round finish
						Acc_Inc <= '1'; -- acc increase
						sgn_j <= 0; -- reset j
						if(Buff_P_Emp='0')then -- at least 1 task in fifo
							Buff_P_Rd <= '1'; -- get new task
							state <= S_Stp4_Lst;
						else
							state <= S_Idle;
						end if;
					else
						Acc_Inc <= '0';
						Buff_P_Rd <= '0';
						Ed <= '0';
						sgn_k <= sgn_j + 1; -- set k
						state <= S_Stp5_Lst; -- sm jump
					end if;
				else
					mC_Latch <= '0';
					sgn_Wr <= '0';
					Acc_Inc <= '0';
					Buff_P_Rd <= '0';
					Ed <= '0';
				end if;
			
			when S_Stp5_Lst =>
--				mBucket_Inc <= '0'; -- no mbucket operation
				Param_jk <= sgn_k;-- get data and gen new idx
				mC_Latch <= '0';
				sgn_Wr <= '0';
				Mem_Sel <= '1'; -- idex mem write operation select
			
				if(Mem_Valid='1')then
					if(sgn_k = Param_sBn-1)then -- last j
						sgn_j <= sgn_j + 1; -- increase j
						state <= S_Stp4_Lst; -- sm jump
					else
						sgn_k <= sgn_k + 1; -- k increase
					end if;
					sgn_Wr_Lst <= '1'; -- wr index to mem for last round
				else
					sgn_Wr_Lst <= '0';
				end if;
				
			when others =>  state <= S_Idle;
		end case;
	end if;
end process;

end rtl;

------------------------------------------------------------------------------------
---- Company: 
---- Engineer: 		Logotorix
---- 
---- Create Date:    11/07/2018 
---- Design Name: 
---- Module Name:    Equihash_GBP_ClsStp4 - Behavioral
---- Project Name: 
---- Target Devices: 
---- Tool versions: 
---- Description: 
----
---- Dependencies: 
----
---- Revision: 
----
---- Additional Comments: 
----
------------------------------------------------------------------------------------
--
--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--
--library work;
--use work.LgGlobal_pkg.all;
--use work.Equihash_pkg.all;
--
--entity Equihash_GBP_CllsStp4 is
--port (
--	LastRound		: in	std_logic;
--	
--	Param_jk		: out	Natural;
--	
--	Mem_Wr			: out	std_logic; 
--	mBucket_Inc		: out	std_logic;
--	Mem_Sel			: out	std_logic;
--	
--	mC_Latch		: out	std_logic;
--	Acc_Inc			: out	std_logic;
--	
--	Buff_P_Rd		: out	std_logic;
--	Buff_P_Emp		: in	std_logic;
--	
--	Ed				: out	std_logic;
--	Bsy				: out	std_logic;
--	
--	Param_sBn		: in	Natural range 0 to gcst_sBucket_MaxCap;
--	
--	clk				: in	std_logic;
--	aclr			: in	std_logic
--);
--end Equihash_GBP_CllsStp4;
--
--architecture rtl of Equihash_GBP_CllsStp4 is
----============================ constant declare ============================--
--
----======================== Altera component declare ========================--
--
----===================== user-defined component declare =====================--
--
----============================= signal declare =============================--
--type typ_state is (S_Idle, S_W, S_Stp4, S_Stp5);
--signal state	: typ_state;
--
--signal sgn_j	: Natural range 0 to gcst_sBucket_MaxCap+1;
--signal sgn_k	: Natural range 0 to gcst_sBucket_MaxCap+1;
----============================ function declare ============================--
--
--begin
--
--process(clk,aclr)
--begin
--	if(aclr='1')then
--		state <= S_Idle;
--		Buff_P_Rd <= '0';
--		mC_Latch <= '0';
--		Mem_Wr <= '0';
--		Mem_Sel <= '0';
--		mBucket_Inc <= '0';
--		Acc_Inc <= '0';
--		Ed <= '0';
--		Bsy <= '0';
--		-- signal
--		sgn_j <= 0;
--		sgn_k <= 0;
--	elsif(rising_edge(clk))then
--		case state is
--			when S_Idle =>
--				Ed <= '0';
--				sgn_j <= 0;
--				mC_Latch <= '0';
--				Mem_Wr <= '0';
--				Acc_Inc <= '0';
--				if(Buff_P_Emp='0')then -- at least 1 task in fifo
--					Buff_P_Rd <= '1'; -- get new task
--					Bsy <= '1';
--					state <= S_W;
--				else
--					Bsy <= '0';
--				end if;
--			
--			when S_W => -- wait 1clk
--				Buff_P_Rd <= '0';
--				Ed <= '0';
--				mC_Latch <= '0';
--				Mem_Wr <= '0';
--				Acc_Inc <= '0';
--				state <= S_Stp4;
--			
----			when S_Stp4 =>
----				Mem_Sel <= '0';
----				mBucket_Inc <= '0';
----				Param_jk <= sgn_j; -- get data, old index and gen new idx
----				mC_Latch <= '1'; -- latch data and new index
----				Mem_Wr <= '1'; -- write old index to ram
----				if(sgn_j=Param_sBn-1)then
----					Ed <= '1';
----					Acc_Inc <= '1';
----					sgn_j <= 0;
----					if(Buff_P_Emp='0')then -- at least 1 task in fifo
----						Buff_P_Rd <= '1'; -- get new task
----						state <= S_W;
----					else
----						state <= S_Idle;
----					end if;
----				else
----					sgn_k <= sgn_j + 1;
----					state <= S_Stp5;
----				end if;
--				
--			when S_Stp4 =>
--				Mem_Sel <= '0';
--				mBucket_Inc <= '0';
--				Param_jk <= sgn_j; -- get data, old index and gen new idx
--				mC_Latch <= '1'; -- latch data and new index
--				Mem_Wr <= '1'; -- write old index to ram
--				if(sgn_j=Param_sBn-1)then
--					Ed <= '1';
--					Acc_Inc <= '1';
--					sgn_j <= 0;
--					if(Buff_P_Emp='0')then -- at least 1 task in fifo
--						Buff_P_Rd <= '1'; -- get new task
--						state <= S_Stp4;
--					else
--						state <= S_Idle;
--					end if;
--				else
--					Acc_Inc <= '0';
--					Buff_P_Rd <= '0';
--					Ed <= '0';
--					sgn_k <= sgn_j + 1;
--					state <= S_Stp5;
--				end if;
--			
--			when S_Stp5 =>
--				mC_Latch <= '0';
--				Param_jk <= sgn_k;-- get data and gen new idx
--				if(LastRound='1')then -- last round 
--					Mem_Wr <= '1'; -- wr index to mem for last round
--					mBucket_Inc <= '0';
--					Mem_Sel <= '1';
--				else
--					Mem_Wr <= '0';
--					mBucket_Inc <= '1'; -- trig bucket
--					Mem_Sel <= '0';
--				end if;
--				
--				if(sgn_k = Param_sBn-1)then
--					sgn_j <= sgn_j + 1;
--					state <= S_Stp4;
--				else
--					sgn_k <= sgn_k + 1; -- sgn_k increase
--				end if;
--			
--			when others =>  state <= S_Idle;
--		end case;
--	end if;
--end process;
--
--end rtl;

