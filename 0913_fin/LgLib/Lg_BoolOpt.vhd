----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    21/05/2018 
-- Design Name: 
-- Module Name:    Lg_BoolOpt - Behavioral
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

entity Lg_BoolOpt is
generic(
	Num				: Positive := 3;
	Typ				: string := "or"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "true" -- "true" "false"
);
port (
	Di			: in	unsigned(Num-1 downto 0);
	Do			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic
);
end Lg_BoolOpt;

architecture rtl of Lg_BoolOpt is
--============================ constant declare ============================--
constant nL		: Natural := Fnc_Int2Wd(Num-1);
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_L		: unsigned(2**(nL+1)-2 downto 0);

--============================ function declare ============================--

begin

i0200: for i in 0 to Num-1 generate
	sgn_L(i) <= Di(i);
end generate i0200;

p0100: if(2**nL /= Num)generate
	p0110: if(Typ = "or" or Typ = "xor" or Typ = "nand")generate
		sgn_L(2**nL-1 downto Num) <= (others => '0');
	end generate p0110;
	p0120: if(Typ = "and" or Typ = "xnor" or Typ = "nor")generate
		sgn_L(2**nL-1 downto Num) <= (others => '1');
	end generate p0120;
end generate p0100;

b01: if(Syn = "true")generate
	t01: if (Typ = "or") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) or 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t01;

	t02: if (Typ = "and") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) and 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t02;

	t03: if (Typ = "xor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) xor 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t03;

	t04: if (Typ = "nand") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) nand 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t04;

	t05: if (Typ = "nor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) nor 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t05;

	t06: if (Typ = "xnor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				process(clk, aclr)
				begin
					if(aclr = '1')then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= '0';
					elsif(rising_edge(clk))then
						sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) xnor 
														  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
					end if;
				end process;
			end generate i0110;
		end generate i0100;
	end generate t06;
end generate b01;

b02: if(Syn = "false")generate
	t01: if (Typ = "or") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) or 
												  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t01;

	t02: if (Typ = "and") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) and 
															 sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t02;

	t03: if (Typ = "xor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) xor 
												  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t03;

	t04: if (Typ = "nand") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) nand 
												  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t04;

	t05: if (Typ = "nor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) nor 
												  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t05;

	t06: if (Typ = "xnor") generate
		i0100: for i in 0 to nL-1 generate
			i0110: for j in 0 to 2**(nL-1-i)-1 generate
				sgn_L(j+(2**(nL+1)-2**(nL-i))) <= sgn_L(j*2+(2**(nL+1)-2**(nL-i+1))) xnor 
												  sgn_L(j*2+1+(2**(nL+1)-2**(nL-i+1)));
			end generate i0110;
		end generate i0100;
	end generate t06;
end generate b02;

Do <= sgn_L(2**(nL+1)-2);

end rtl;
