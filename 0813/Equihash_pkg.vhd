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
-- sys param
constant gcst_Equihash_n		: Natural := 200;
constant gcst_Equihash_k		: Natural := 9;
constant gcst_Round				: Natural := gcst_Equihash_k;-- 9

constant gcst_N_Chunk			: Natural := gcst_Equihash_k+1; -- 10 = 9+1
constant gcst_W_Chunk			: Natural := gcst_Equihash_n / (gcst_N_Chunk); -- 20 = 200/10

constant gcst_W_Nounce			: Natural := 32; -- Byte
constant gcst_W_Idx				: Natural := 4; -- Byte

constant gcst_mBucket_Width		: Natural := 14;
constant gcst_mBucket_Offset	: Natural := 0;
constant gcst_mBucket_Num		: Natural := 2**gcst_mBucket_Width; -- 2**14
constant gcst_mBucket_MaxCap	: Natural := 3*(2**(gcst_W_Chunk+1-gcst_mBucket_Width));--3*(2**(20+1-14))=3*(2**7);

constant gcst_sBucket_Width		: Natural := gcst_W_Chunk-gcst_mBucket_Width; -- 20-14=6
constant gcst_sBucket_Offset	: Natural := gcst_mBucket_Width; -- 14
constant gcst_sBucket_Num		: Natural := 2**gcst_sBucket_Width; -- 2**6
constant gcst_sBucket_MaxCap	: Natural := 17; -- 17

--============================================================
-- only for test
-- mem port param(data)
constant gcst_WA_Mem			: Natural := 32;
constant gcst_WD_Mem			: Natural := 256;
-- mem addr param(data)
constant gcst_AB_MemD_BaseA		: Natural := 0;
constant gcst_AB_MemD_BaseB		: Natural := gcst_mBucket_MaxCap*gcst_mBucket_Num; -- 2**14 * 3*(2**7) = 3*(2**21)
constant gcst_AB_MemD_Sect		: Natural := gcst_mBucket_MaxCap; -- 3*(2**7)
-- mem addr param(Idx)
constant gcst_AB_MemIdx_Base	: Natural := 0; -- gcst_mBucket_MaxCap*gcst_mBucket_Num*2;
constant gcst_AB_MemIdx_Sect	: Natural := 2**21+2**19;
--============================================================

-- cache port param(data)
constant gcst_WA_Cache			: Natural := 16;
constant gcst_WD_Cache_Data		: Natural := gcst_W_Chunk * gcst_N_Chunk; -- 20*10=200
constant gcst_WD_Cache_Idx		: Natural := 24;
constant gcst_WD_Cache_Stp		: Natural := 8;
constant gcst_WD_Cache_Apdix	: Natural := gcst_WD_Cache_Idx + gcst_WD_Cache_Stp; -- 24+8=32
-- cache addr param(data)
constant gcst_AB_Cache			: Natural := 0;
constant gcst_sBucket_Sect		: Natural := gcst_sBucket_MaxCap; -- 17

constant gcst_WD_Mem_Apdix		: Natural := gcst_WD_Cache_Apdix; -- 32
-- cache addr param(Idx)
constant gcst_Size_idxCache		: Natural := 2**gcst_Round; -- 512
constant gcst_WD_idxCache		: Natural := gcst_WD_Cache_Apdix; -- 32
constant gcst_WA_idxCache		: Natural := Fnc_Int2Wd(gcst_Size_idxCache-1); -- 9

-- 
constant gcst_WD_sBn			: Natural := Fnc_Int2Wd(gcst_sBucket_MaxCap); -- 5
constant gcst_WD_ParamP			: Natural := Fnc_Int2Wd(gcst_sBucket_Num-1); -- 6
constant gcst_WD_mBn			: Natural := Fnc_Int2Wd(gcst_mBucket_MaxCap); -- 8
constant gcst_WD_ParamQ			: Natural := Fnc_Int2Wd(gcst_mBucket_Num-1); -- 14

--types
type typ_1D_Mem_D is array (natural range<>) of unsigned(gcst_WD_Mem-1 downto 0);
type typ_1D_Mem_A is array (natural range<>) of unsigned(gcst_WA_Mem-1 downto 0);
type typ_1D_MemApdix_D is array (natural range<>) of unsigned(gcst_WD_Mem_Apdix-1 downto 0);
type typ_1D_MemApdix_A is array (natural range<>) of unsigned(gcst_WA_Mem-1 downto 0);
type typ_1D_Idx_D is array (natural range<>) of unsigned(gcst_WD_idxCache-1 downto 0);
type typ_1D_Idx_A is array (natural range<>) of unsigned(gcst_WA_idxCache-1 downto 0);

type typ_ThTsk is 
record 
	mBn					: Natural range 0 to gcst_mBucket_MaxCap;
	Param_q				: Natural range 0 to gcst_mBucket_Num-1;
	AB_IdxArrSub		: unsigned(gcst_WA_Mem-1 downto 0);
end record;

-- user defined module delay
constant gcst_BucketDisp_RtlDL_Get		: Natural := gcst_LgRamCounter_RtlDL + 1; -- 5
constant gcst_BucketDisp_RtlDL_pp		: Natural := gcst_LgRamCounter_RtlDL + 2; -- 6
constant gcst_BucketRt2x2_RtlDL			: Natural := 1;
constant gcst_BucketMix_RtlDL			: Natural := 1;

constant gcst_AddrAuxCalc_RtlDL			: Natural := 2;

constant gcst_LpmRam_RtlDL_Rd			: Natural := 2; -- read ram data
constant gcst_LpmRam_RtlDL_Wr			: Natural := 1; -- write ram data

constant gcst_IdxCache_RtlDL_Rd			: Natural := 4;

-- all purpose funtion
		
end package;

PACKAGE BODY Equihash_pkg IS


END Equihash_pkg;