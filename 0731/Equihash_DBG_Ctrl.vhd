----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    27/06/2018 
-- Design Name: 
-- Module Name:    Equihash_DBG_Ctrl - Behavioral
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

entity Equihash_DBG_Ctrl is
generic(
	Num_Idx				: Natural := 10
);
port (
	-- Bucket router config
	BucketRt_Config		: out	std_logic; -- high priority
	BucketRt_IncSet		: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0)
	BucketRt_GetSet		: out	std_logic; -- '0': A->A, B->B; '1': A->B, B->A (fixed 0 no care)
	BucketRt_MemChSel	: out	std_logic; -- '0': A->o; '1': B->o (fixed 0)
	-- Bucket initial
	Bucket_Init			: out	std_logic;
	Bucket_Rdy			: in	std_logic;
	-- Bucket param set
	Bucket_AB_Buff		: out	unsigned(gcst_WA_Mem-1 downto 0); -- fixed 0
	Bucket_ChunkSel		: out	Natural range 0 to gcst_N_Chunk-1; -- fixed 0
	
	Idx					: out	Natural;
	
	Trg					: out	std_logic;
	Sel					: out	std_logic;
	Valid				: in	std_logic;
	
	St					: in	std_logic;
	Ed					: out	std_logic;
	Bsy					: out	std_logic;
	
	clk					: in	std_logic;
	aclr				: in	std_logic
);
end Equihash_DBG_Ctrl;

architecture rtl of Equihash_DBG_Ctrl is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Confg, S_Init, S_Rdy, S_Trg1, S_Trg2);
signal state			: typ_state;

signal sgn_Rdy		: std_logic;
signal sgn_cnt		: Natural;
--============================ function declare ============================--

begin

BucketRt_IncSet <= '0';
BucketRt_GetSet <= '0';
BucketRt_MemChSel <= '0';

Bucket_AB_Buff <= to_unsigned(gcst_AB_MemA,gcst_WA_Mem); -- fixed always store to mem block A
Bucket_ChunkSel <= 0; -- always compare first 20bit

process(aclr,clk)
begin
	if(aclr='1')then
		state <= S_Idle;
		BucketRt_Config <= '0';
		Bucket_Init <= '0';
		Trg <= '0';
		Sel <= '0';
		Ed <= '0';
		Bsy <= '0';
		-- signal
		sgn_Rdy <= '1';
		sgn_cnt <= 0;
	elsif(rising_edge(clk))then
		sgn_Rdy <= Bucket_Rdy;
		case state is
			when S_Idle =>
				Ed <= '0';
				sgn_cnt <= 0;
				if(St = '1')then
					state <= S_Confg;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
			
			when S_Confg =>
				BucketRt_Config <= '1';
				state <= S_Init;
			
			when S_Init =>
				BucketRt_Config <= '0';
				Bucket_Init <= '1';
				state <= S_Rdy;
			
			when S_Rdy =>
				Bucket_Init <= '0';
				if(sgn_Rdy = '0' and Bucket_Rdy = '1')then -- wait Init process finish rising edge
					state <= S_Trg1;
				end if;
			
			when S_Trg1 =>
				if(sgn_cnt = Num_Idx)then -- last number
					Ed <= '1';
					Trg <= '0';
					Sel <= '0';
					state <= S_Idle;
				else
					if(Valid = '1')then
						Idx <= sgn_cnt;
						Trg <= '1';
						Sel <= '0';
						state <= S_Trg2;
					else
						Trg <= '0';
					end if;
				end if;
				
			when S_Trg2 =>
				Idx <= sgn_cnt;
				Trg <= '1';
				Sel <= '1';
				sgn_cnt <= sgn_cnt + 1;
				state <= S_Trg1;
			
			when others => State <= S_Idle;
		end case;
	end if;
end process;

end rtl;

