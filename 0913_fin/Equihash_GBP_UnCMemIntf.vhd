----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    26/06/2018 
-- Design Name: 
-- Module Name:    Equihash_GBP_UnCMemIntf - Behavioral
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

--LIBRARY altera_mf;
--USE altera_mf.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

library work;
use work.LgGlobal_pkg.all;
use work.Equihash_pkg.all;

entity Equihash_GBP_UnCMemIntf is
generic(
	Device_Family	: string := "Cyclone V"
);
port (
	Mem_Di		: in	unsigned(gcst_WD_idxCache-1 downto 0);
	Mem_RdAck	: in	std_logic;
	
	Cache_Di	: out	unsigned(gcst_WD_idxCache-1 downto 0);
	Cache_A_Wr	: out	unsigned(gcst_WA_idxCache-1 downto 0);
	Cache_Wr	: out	std_logic;
	Cache_A_Rst	: in	std_logic;
	
	isLast		: in	std_logic;
	
	Valid		: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Equihash_GBP_UnCMemIntf;

architecture rtl of Equihash_GBP_UnCMemIntf is
--============================ constant declare ============================--

--======================== Altera component declare ========================--
component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL := gcst_Size_idxCache; -- 512
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL := gcst_WD_idxCache;
	lpm_widthu					: NATURAL := gcst_WA_idxCache; -- 9
	overflow_checking			: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab						: STRING := "ON"
);
port (
	data				: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				: IN STD_LOGIC ;

	q					: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				: IN STD_LOGIC ;
	
	empty				: OUT STD_LOGIC ;

	clock				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;
--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_state is (S_Idle, S_Wr1, S_Wr2, S_Wrlst, S_W);
signal state			: typ_state;

signal sgn_fifo_empty	: std_logic;
signal sgn_fifo_rd		: std_logic;
signal sgn_fifo_Do		: STD_LOGIC_VECTOR(gcst_WD_idxCache-1 downto 0);
signal sgn_fifo_wr		: std_logic;
signal sgn_fifo_Di		: STD_LOGIC_VECTOR(gcst_WD_idxCache-1 downto 0);

signal sgn_cnt		: Natural range 0 to gcst_Size_idxCache;

signal sgn_Idx		: unsigned(gcst_WD_Cache_Idx-1 downto 0); -- 24
signal sgn_Stp		: unsigned(gcst_WD_Cache_Stp-1 downto 0); -- 8
--============================ function declare ============================--

begin

sgn_fifo_wr <= Mem_RdAck;
sgn_fifo_Di <= std_logic_vector(Mem_Di);

inst01: scfifo
port map(
	data				=> sgn_fifo_Di,--(IO): IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_fifo_wr,--(IO): IN STD_LOGIC ;

	q					=> sgn_fifo_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_fifo_rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_fifo_empty,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_Idx <= unsigned(sgn_fifo_Do(gcst_WD_Cache_Idx-1 downto 0));
sgn_Stp <= unsigned(sgn_fifo_Do(gcst_WD_idxCache-1 downto gcst_WD_Cache_Idx));

process(clk,aclr)
begin
	if(aclr='1')then
		state <= S_Idle;
		Cache_Wr <= '0';
		sgn_fifo_rd <= '0';
		sgn_cnt <= 0;
		Valid <= '0';
	elsif(rising_edge(clk))then
		case state is
			when S_Idle =>
				Cache_Wr <= '0';
				if(sgn_fifo_empty = '0')then
					sgn_fifo_rd <= '1';
					state <= S_W;
				end if;
				if(Cache_A_Rst='1')then
					sgn_cnt <= 0;
					Valid <= '0';
				end if;
			
			when S_W =>
				sgn_fifo_rd <= '0';
				Cache_Wr <= '0';
				if(isLast='1')then-- last data
					state <= S_WrLst;
				else
					state <= S_Wr1;
				end if;
			
			when S_Wr1 =>
				if(sgn_Stp = 0)then -- high 8bit equal to 0 allude to invalid
					Valid <= '1';
				end if;
				Cache_Di <= to_unsigned(0,gcst_WD_Cache_Stp) & 
							sgn_Idx;-- low 24bit
				Cache_Wr <= '1';
				Cache_A_Wr <= to_unsigned(sgn_cnt, gcst_WA_idxCache);
				sgn_cnt <= sgn_cnt + 1;
				state <= S_Wr2;
			
			when S_Wr2 =>
				-- low 24bit + high 8bit
				Cache_Di <= (to_unsigned(0,gcst_WD_Cache_Stp) & sgn_Idx) +
							(to_unsigned(0,gcst_WD_Cache_Idx) & sgn_Stp);
				Cache_Wr <= '1';
				Cache_A_Wr <= to_unsigned(sgn_cnt, gcst_WA_idxCache);
				sgn_cnt <= sgn_cnt + 1;
				if(sgn_fifo_empty = '0')then
					sgn_fifo_rd <= '1';
					state <= S_W;
				else
					state <= S_Idle;
				end if;
				
			when S_WrLst =>
				Valid <= '0';
				Cache_Di <= to_unsigned(0,gcst_WD_Cache_Stp) & 
							sgn_Idx;-- low 24bit
				Cache_Wr <= '1';
				Cache_A_Wr <= to_unsigned(sgn_cnt, gcst_WA_idxCache);
				sgn_cnt <= sgn_cnt + 1;
				if(sgn_fifo_empty = '0')then
					sgn_fifo_rd <= '1';
					state <= S_W;
				else
					state <= S_Idle;
				end if;
				
			when others => state <= S_Idle;
		end case;
	end if;
end process;

end rtl;
