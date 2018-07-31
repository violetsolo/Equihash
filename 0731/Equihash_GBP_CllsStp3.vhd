----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/07/2018 
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
	Device_Family	: string := "Cyclone V"
);
port (
	sBucket_Init	: out	std_logic;
	sBucket_Rdy		: in	std_logic;
	
	sBucket_Get		: out	std_logic;
	sBucket_GetIdx	: out unsigned(gcst_W_Chunk-1 downto 0); -- size same as chunk data
	SBucket_Cnt		: in	Natural range 0 to gcst_sBucket_MaxCap;
	
	Cache_Sel		: out	std_logic; -- '1' current sm get control right
	Acc_Clr			: out	std_logic;
	
	LastRound		: in	std_logic;
	
	Buff_P_D		: out	unsigned(gcst_WD_sBn+gcst_WD_ParamP-1 downto 0);
	Buff_P_Wr		: out	std_logic;
	Buff_P_Full		: in	std_logic;
	Buff_P_Emp		: in	std_logic;
	
	ThEd_Req		: out	std_logic;
	ThEd_Ack		: in	std_logic;
	InfoLst_Wr		: out	std_logic;
	
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy				: out	std_logic;
	
	Tsk_Bsy			: in	std_logic;
	
	clk				: in	std_logic;
	aclr			: in	std_logic
);
end Equihash_GBP_CllsStp3;

architecture rtl of Equihash_GBP_CllsStp3 is
--============================ constant declare ============================--
constant cst_FIFO_Deepth		: Natural := 64;
constant cst_FIFO_rem			: Natural := gcst_BucketDisp_RtlDL_Get + 5;
--======================== Altera component declare ========================--
component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL := cst_FIFO_Deepth;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL := gcst_WD_sBn+gcst_WD_ParamP;
	lpm_widthu					: NATURAL := Fnc_Int2Wd(cst_FIFO_Deepth-1); -- log2(128)
	almost_full_value 			: Natural := cst_FIFO_Deepth - cst_FIFO_rem;
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
	almost_full			: out std_logic;

	clock				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;

--===================== user-defined component declare =====================--
component Lg_SingalPipe
generic(
	Width_D			: Positive;
	Num_Pipe		: Positive
);
port (
	di			: in	unsigned(Width_D-1 downto 0);
	do			: out	unsigned(Width_D-1 downto 0);
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
type typ_state_G is (S_Idle, S_GetCnt);
signal state_G				: typ_state_G;
type typ_state_M is (S_Idle, S_AckW, S_InitW, S_GetW, S_Fin, S_FinW);
signal state_M				: typ_state_M;

signal sgn_p				: Natural range 0 to gcst_sBucket_Num;
signal sgn_ParamP			: unsigned(gcst_WD_ParamP-1 downto 0);

signal sgn_sBn				: Natural range 0 to gcst_sBucket_MaxCap;

signal sgn_StGet			: std_logic;
signal sgn_EdGet			: std_logic;

signal sgn_sBGet		: std_logic;
signal sgn_sBRdy		: std_logic;

signal sgn_FIFO_C_Do		: std_logic_vector(gcst_WD_sBn+gcst_WD_ParamP-1 downto 0);
signal sgn_FIFO_C_Di		: std_logic_vector(gcst_WD_sBn+gcst_WD_ParamP-1 downto 0);
signal sgn_FIFO_C_Rd		: std_logic;
signal sgn_FIFO_C_Wr		: std_logic;
signal sgn_FIFO_C_FUll		: std_logic;
signal sgn_FIFO_C_Emp		: std_logic;

signal sgn_Tsk_ParamP		: unsigned(gcst_WD_ParamP-1 downto 0);
signal sgn_Tsk_sBn			: unsigned(gcst_WD_sBn-1 downto 0);

signal sgn_sBInit			: std_logic;
signal sgn_sBInitBsy		: std_logic;

signal sgn_FinWCnt			: Natural;

-- delay
constant cst_sBGet_DL		: Natural := gcst_BucketDisp_RtlDL_Get; -- DL5
signal sgn_sBGet_DL			: unsigned(0 downto 0);
--
constant cst_ParamP_DL		: Natural := gcst_BucketDisp_RtlDL_Get; -- DL5
signal sgn_ParamP_DL		: unsigned(gcst_WD_ParamP-1 downto 0);
--
constant cst_FIFORd_DL		: Natural := 1;
signal sgn_FIFORd_DL		: unsigned(0 downto 0);
--
constant cst_FinW_DL		: Natural := gcst_LpmRam_RtlDL_Rd + 
										gcst_AddrAuxCalc_RtlDL + 
										gcst_LpmRam_RtlDL_Rd + 
										1 + 1 + 1; -- mux / cmp / Inc -- 9
--============================ function declare ============================--

begin

inst01: scfifo
port map(
	data				=> sgn_FIFO_C_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_C_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_C_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_C_Rd,--: IN STD_LOGIC ;
	
	empty				=> sgn_FIFO_C_Emp,--: OUT STD_LOGIC ;
	almost_full			=> sgn_FIFO_C_FUll,--: out std_logic;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

-- get sBucket cnt (SM)
sBucket_Get <= sgn_sBGet;

process(clk,aclr)
begin
	if(aclr='1')then
		state_G <= S_Idle;
		sgn_sBGet <='0';
		-- signal
		sgn_p <= 0;
		sgn_EdGet <= '0';
	elsif(rising_edge(clk))then
		sBucket_GetIdx <= to_unsigned(sgn_p,sBucket_GetIdx'length) sll gcst_sBucket_Offset;
		sgn_ParamP <= to_unsigned(sgn_p,gcst_WD_ParamP);
		case state_G is
			when S_Idle =>
				sgn_p <= 0;
				sgn_EdGet <= '0';
				sgn_sBGet <='0';
				if(sgn_StGet='1')then
					state_G <= S_GetCnt;
				end if;
			
			when S_GetCnt =>
				if(sgn_FIFO_C_FUll = '0')then
					sgn_sBGet <='1';
					sgn_p <= sgn_p + 1;
				else
					sgn_sBGet <='0';
				end if;
				
				if(sgn_p = gcst_sBucket_Num-1 and sgn_FIFO_C_FUll = '0')then
					sgn_EdGet <= '1';
					state_G <= S_Idle;
				end if;
				
			when others => state_G <= S_Idle;
		end case;
	end if;
end process;

-- connect FIFO input
sgn_FIFO_C_Di <= std_logic_vector(sgn_ParamP_DL) & -- DL5
				 std_logic_vector(to_unsigned(SBucket_Cnt,gcst_WD_sBn)); -- io
sgn_FIFO_C_Wr <= sgn_sBGet_DL(0); -- DL5
-- connect FIFO output (logic)
sgn_FIFO_C_Rd <= (not sgn_FIFO_C_Emp) and (not Buff_P_Full);
sgn_Tsk_ParamP <= unsigned(sgn_FIFO_C_Do(gcst_WD_sBn+gcst_WD_ParamP-1 downto gcst_WD_sBn));
sgn_Tsk_sBn <= unsigned(sgn_FIFO_C_Do(gcst_WD_sBn-1 downto 0));

-- cnt deal and output
process(clk) -- 1clk delay
begin
	if(rising_edge(clk))then
		Buff_P_D <= sgn_Tsk_ParamP & sgn_Tsk_sBn;
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		Buff_P_Wr <= '0';
	elsif(rising_edge(clk))then
		if(sgn_Tsk_sBn<=1)then
			Buff_P_Wr <= '0';
		else
			Buff_P_Wr <= sgn_FIFORd_DL(0); -- DL1+1=DL2
		end if;
	end if;
end process;

-- task control
sBucket_Init <= sgn_sBInit;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_sBRdy <= '1';
		sgn_sBInitBsy <= '0';
	elsif(rising_edge(clk))then
		sgn_sBRdy <= sBucket_Rdy;
		if(sgn_sBInit='1')then
			sgn_sBInitBsy <= '1';
		elsif(sgn_sBRdy = '0' and sBucket_Rdy = '1')then -- rising edge
			sgn_sBInitBsy <= '0';
		end if;
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		state_M <= S_Idle;
		Cache_Sel <= '0';
		Acc_Clr <= '0';
		Ed <= '0';
		Bsy <= '0';
		ThEd_Req <= '0';
		InfoLst_Wr <= '0';
		-- signal
		sgn_StGet <= '0';
		sgn_sBInit <= '0';
		sgn_FinWCnt <= 0;
	elsif(rising_edge(clk))then
		case state_M is
			when S_AckW =>
				sgn_sBInit <= '0';
				if(ThEd_Ack='1')then
					ThEd_Req <= '0';
					InfoLst_Wr <= '1';
					state_M <= S_InitW;
				end if;
			
			when S_InitW =>
				InfoLst_Wr <= '0';
				sgn_sBInit <= '0';
				if(sgn_sBInitBsy='0')then
					Ed <= '1';
					state_M <= S_Idle;
				end if;
			
			when S_Idle =>
				Ed <= '0';
				if(St = '1')then
					state_M <= S_GetW;
					Cache_Sel <= '1';
					sgn_StGet <= '1';
					Acc_Clr <= '1';
					Bsy <= '1';
				else
					Cache_Sel <= '0';
					Bsy <= '0';
				end if;
				
			when S_GetW =>
				sgn_StGet <= '0';
				Acc_Clr <= '0';
				if(sgn_EdGet='1')then
					state_M <= S_Fin;
				end if;
			
			when S_Fin =>
				sgn_FinWCnt <= 0;
				if(Tsk_Bsy='0' and Buff_P_Emp='1' and sgn_FIFO_C_Emp='1')then
					if(LastRound='1')then
						state_M <= S_FinW;
					else
						state_M <= S_InitW;
						sgn_sBInit <= '1';
					end if;
--					state_M <= S_FinW;
				end if;
			
			when S_FinW =>
				sgn_FinWCnt <= sgn_FinWCnt + 1;
				if(sgn_FinWCnt = cst_FinW_DL-1)then -- 
					state_M <= S_AckW;
					sgn_sBInit <= '1';
					ThEd_Req <= '1'; -- hold until ack
				end if;
			
			when others => 
				state_M <= S_InitW;
				sgn_sBInit <= '1';
		end case;
	end if;
end process;

-- delay
instPP01: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_sBGet_DL)
port map(di => Fnc_STD2U0(sgn_sBGet), do => sgn_sBGet_DL, clk => clk, aclr => aclr);
--
instPP02: Lg_SingalPipe
generic map(Width_D => gcst_WD_ParamP, Num_Pipe => cst_ParamP_DL)
port map(di => sgn_ParamP, do => sgn_ParamP_DL, clk => clk, aclr => '0');
--
instPP03: Lg_SingalPipe
generic map(Width_D => 1, Num_Pipe => cst_FIFORd_DL)
port map(di => Fnc_STD2U0(sgn_FIFO_C_Rd), do => sgn_FIFORd_DL, clk => clk, aclr => aclr);

end rtl;

