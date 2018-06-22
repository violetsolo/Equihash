----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    04/06/2018 
-- Design Name: 
-- Module Name:    WorkGeneral_pkg - pakage
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

package Blake2b_pkg is
--constants
constant gcst_Blake_SubWW		: Positive := 8; -- word width
constant gcst_Blake_SubWn		: Positive := 16; -- Number or word
constant gcst_Blake_WW			: Positive := gcst_Blake_SubWn*gcst_Blake_SubWW; -- 128
constant gcst_Blake_Round		: Positive := 12; -- mix round

constant gcst_Blake_MixGDL		: Positive := 4; -- mix G function delay
constant gcst_Blake_Gn			: Positive := 2; -- 
constant gcst_Blake_Vn			: Positive := 2; -- 

constant gcst_BlakeLite_RtlDL		: Positive := gcst_Blake_MixGDL * gcst_Blake_Round * gcst_Blake_Gn * gcst_Blake_Vn + 1; -- +1 for xor

type typ_VMix_Tbl is array (0 to 1, 0 to gcst_Blake_SubWn-1) of Integer;
constant cst_VMix_Tbl : typ_VMix_Tbl := (
	(0, 4,  8, 12, 1, 5,  9, 13, 2, 6, 10, 14, 3, 7, 11, 15),
	(0, 5, 10, 15, 1, 6, 11, 12, 2, 7,  8, 13, 3, 4,  9, 14)
);

type typ_Sigma_Tbl is array (0 to gcst_Blake_Round-1, 0 to gcst_Blake_SubWn-1) of Integer;
constant cst_Sigma_Tbl : typ_Sigma_Tbl := (
	( 0,	 1,	 2,	 3,	 4,	 5,	 6,	 7,	 8,	 9,	10,	11,	12,	13,	14,	15),
	(14,	10,	 4,	 8,	 9,	15,	13,	 6,	 1,	12,	 0,	 2,	11,	 7,	 5,	 3),
	(11,	 8,	12,	 0,	 5,	 2,	15,	13,	10,	14,	 3,	 6,	 7,	 1,	 9,	 4),
	( 7,	 9,	 3,	 1,	13,	12,	11,	14,	 2,	 6,	 5,	10,	 4,	 0,	15,	 8),
	( 9,	 0,	 5,	 7,	 2,	 4,	10,	15,	14,	 1,	11,	12,	 6,	 8,	 3,	13),
	( 2,	12,	 6,	10,	 0,	11,	 8,	 3,	 4,	13,	 7,	 5,	15,	14,	 1,	 9),
	(12,	 5,	 1,	15,	14,	13,	 4,	10,	 0,	 7,	 6,	 3,	 9,	 2,	 8,	11),
	(13,	11,	 7,	14,	12,	 1,	 3,	 9,	 5,	 0,	15,	 4,	 8,	 6,	 2,	10),
	( 6,	15,	14,	 9,	11,	 3,	 0,	 8,	12,	 2,	13,	 7,	 1,	 4,	10,	 5),
	(10,	 2,	 8,	 4,	 7,	 6,	 1,	 5,	15,	11,	 9,	14,	 3,	12,	13,	 0),
	( 0,	 1,	 2,	 3,	 4,	 5,	 6,	 7,	 8,	 9,	10,	11,	12,	13,	14,	15),
	(14,	10,	 4,	 8,	 9,	15,	13,	 6,	 1,	12,	 0,	 2,	11,	 7,	 5,	 3)
);

constant cst_ROR		: typ_1D_Nat(0 to 4-1) := (32, 24, 16, 63);

type typ_IV_Tbl is array (0 to gcst_Blake_WW/2-1) of unsigned(gcst_WW-1 downto 0);
constant cst_IV_Tbl : typ_IV_Tbl := (
	x"08", x"c9", x"bc", x"f3", x"67", x"e6", x"09", x"6a", 	
	x"3b", x"a7", x"ca", x"84", x"85", x"ae", x"67", x"bb", 
	x"2b", x"f8", x"94", x"fe", x"72", x"f3", x"6e", x"3c", 
	x"f1", x"36", x"1d", x"5f", x"3a", x"f5", x"4f", x"a5", 
	x"d1", x"82", x"e6", x"ad", x"7f", x"52", x"0e", x"51", 
	x"1f", x"6c", x"3e", x"2b", x"8c", x"68", x"05", x"9b", 	
	x"6b", x"bd", x"41", x"fb", x"ab", x"d9", x"83", x"1f",	
	x"79", x"21", x"7e", x"13", x"19", x"cd", x"e0", x"5b"
	
);

--types
type typ_1D_Blake8W		is array (natural range<>) of unsigned(gcst_Blake_SubWW*gcst_WW-1 downto 0);

type typ_Blake_Param is 
record 
	Digest_Len		: unsigned(1*gcst_WW-1 downto 0); -- 1
	Key_Len			: unsigned(1*gcst_WW-1 downto 0); -- 2
	Fanout			: unsigned(1*gcst_WW-1 downto 0); -- 3
	Deepth			: unsigned(1*gcst_WW-1 downto 0); -- 4
	Leaf_Len			: unsigned(4*gcst_WW-1 downto 0); -- 8
	Node_Offset		: unsigned(4*gcst_WW-1 downto 0); -- 12
	Xof_Len			: unsigned(4*gcst_WW-1 downto 0); -- 16
	Node_Deepth		: unsigned(1*gcst_WW-1 downto 0); -- 17
	Inner_Len		: unsigned(1*gcst_WW-1 downto 0); -- 18
	Rvs				: unsigned(14*gcst_WW-1 downto 0); -- 32
	Salt				: unsigned(16*gcst_WW-1 downto 0); -- 48
	Personalization	: unsigned(16*gcst_WW-1 downto 0); -- 64
end record;

-- all purpose funtion

end package;



PACKAGE BODY Blake2b_pkg IS



END Blake2b_pkg;