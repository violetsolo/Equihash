----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Lg_BMix_MidWare_pkg - pakage
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

package Lg_BMix_MidWare_pkg is
--constants
constant gcst_AM_WidthData		: Positive := 256; -- word width

constant gcst_AM_SelDL			: Positive := 3;
constant gcst_AM_SelORamDL		: Positive := 4;

--types
type typ_AM_1D_Data		is array (natural range<>) of unsigned(gcst_AM_WidthData-1 downto 0);

end package;

PACKAGE BODY Lg_BMix_MidWare_pkg IS


END Lg_BMix_MidWare_pkg;