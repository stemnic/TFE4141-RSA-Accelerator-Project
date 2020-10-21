library ieee; 
use ieee.std_logic_1164.all; 
-- use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.env.stop;

entity exponentiation_tb is
	generic (
		C_block_size : integer := 256
	);
end exponentiation_tb;


architecture expBehave of exponentiation_tb is

	signal message 		: STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
	signal key 			: STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
	signal valid_in 	: STD_LOGIC;
	signal ready_in 	: STD_LOGIC;
	signal ready_out 	: STD_LOGIC;
	signal valid_out 	: STD_LOGIC;
	signal start_calc   : STD_LOGIC;
	signal done_calc	: STD_LOGIC;
	signal result 		: STD_LOGIC_VECTOR(C_block_size-1 downto 0);
	signal modulus 		: STD_LOGIC_VECTOR(C_block_size-1 downto 0);
	signal clk 			: STD_LOGIC := '0';
	signal restart 		: STD_LOGIC;
	signal reset_n 		: STD_LOGIC;
	constant clk_half_period : time := 0.5 ns;

begin
--	i_exponentiation : entity work.exponentiation
--		port map (
--			message   => message  ,
--			key       => key      ,
--			valid_in  => valid_in ,
--			ready_in  => ready_in ,
--			ready_out => ready_out,
--			valid_out => valid_out,
--			result    => result   ,
--			modulus   => modulus  ,
--			clk       => clk      ,
--			reset_n   => reset_n
--		);
	
	i_blakley : entity work.blakley
		port map (
			message   => message  ,
			key       => key      ,
			start_calc  => start_calc ,
			done_calc => done_calc,
			result    => result   ,
			modulus   => modulus  ,
			clk       => clk      ,
			reset_n   => reset_n
		);
	clk <= not clk after clk_half_period;
	tb1 : process
		begin
--			key <= (others => '0');
			key <=  std_logic_vector(to_unsigned(20, key'length));
			message <=  std_logic_vector(to_unsigned(1337, message'length));
--			modulus <=  x"880A504783F52B6837819485374E67256A270C1B74D9779D86DEDA9CE4FE3F33";
            modulus <= std_logic_vector(to_unsigned(100, modulus'length));
			reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc <= '1';
			wait for 1150 ns;
			stop;
	end process;


end expBehave;
