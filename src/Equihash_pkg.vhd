----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    11/06/2018 
-- Design Name: 
-- Module Name:    Equihash_pkg - pakage
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
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.LgGlobal_pkg.all;

package Equihash_pkg is
--constants
constant gcst_Round				: Natural := 10;
constant gcst_WA_Mem			: Natural := 32;
constant gcst_WD_Mem			: Natural := 256;
constant gcst_W_Chunk			: Natural := 20;
constant gcst_N_Chunk			: Natural := gcst_Round; -- 10 = 200/20

constant gcst_WA_Cache			: Natural := 16;
constant gcst_WD_Cache_Data		: Natural := gcst_W_Chunk * gcst_N_Chunk; -- 20*10=200
constant gcst_WD_Cache_Idx		: Natural := 24;
constant gcst_WD_Cache_Stp		: Natural := 8;
constant gcst_WD_Cache_Apdix	: Natural := gcst_WD_Cache_Idx + gcst_WD_Cache_Stp; -- 24+8=32

constant gcst_WD_Mem_Apdix		: Natural := gcst_WD_Cache_Apdix; -- 32

constant gcst_Size_Idx			: Natural := 2**(gcst_Round-1); -- 512
constant gcst_WD_Idx			: Natural := gcst_WD_Cache_Apdix; -- 32
constant gcst_WA_Idx			: Natural := Fnc_Int2Wd(gcst_Size_Idx-1); -- 9

--types
type typ_1D_Mem_D is array (natural range<>) of unsigned(gcst_WD_Mem-1 downto 0);
type typ_1D_Mem_A is array (natural range<>) of unsigned(gcst_WA_Mem-1 downto 0);
type typ_1D_MemApdix_D is array (natural range<>) of unsigned(gcst_WD_Mem_Apdix-1 downto 0);
type typ_1D_MemApdix_A is array (natural range<>) of unsigned(gcst_WA_Mem-1 downto 0);
type typ_1D_Idx_D is array (natural range<>) of unsigned(gcst_WD_Idx-1 downto 0);
type typ_1D_Idx_A is array (natural range<>) of unsigned(gcst_WA_Idx-1 downto 0);

-- user defined module delay
constant gcst_BucketDisp_RtlDL_Get		: Natural := gcst_LgRamCounter_RtlDL + 1; -- 4
constant gcst_BucketDisp_RtlDL_pp		: Natural := gcst_LgRamCounter_RtlDL + 2; -- 5
constant gcst_BucketRt2x2_RtlDL			: Natural := 1;
constant gcst_AddrAuxCalc_RtlDL			: Natural := 2;
constant gcst_LpmRam_RtlDL_Rd			: Natural := 2; -- read ram data
constant gcst_LpmRam_RtlDL_Wr			: Natural := 1; -- write ram data

constant gcst_IdxCache_RtlDL_Rd			: Natural := 4;

-- all purpose funtion
		
end package;

PACKAGE BODY Equihash_pkg IS


END Equihash_pkg;