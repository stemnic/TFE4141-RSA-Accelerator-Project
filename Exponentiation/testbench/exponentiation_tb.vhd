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
    signal start_calc_BL   : STD_LOGIC;
	signal done_calc	: STD_LOGIC;
    signal done_calc_BL	: STD_LOGIC;
	signal result 		: STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal result_BL    : STD_LOGIC_VECTOR(C_block_size-1 downto 0);

	signal modulus 		: STD_LOGIC_VECTOR(C_block_size-1 downto 0);
	signal clk 			: STD_LOGIC := '0';
	signal restart 		: STD_LOGIC;
	signal reset_n 		: STD_LOGIC;
	constant clk_half_period : time := 0.5 ns;

begin


	--   # KEY N
	--   99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d
	--   # KEY E
	--   0000000000000000000000000000000000000000000000000000000000010001
	--   # KEY D
	--   0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9
	--   

	i_LR_bin : entity work.LR_binary
		port map (
			message   => message  ,
			key       => key      ,
			start_calc  => start_calc ,
			done_calc_LR => done_calc,
			result_LR    => result   ,
			modulus   => modulus  ,
			clk       => clk      ,
			reset_n   => reset_n
		);
		
	i_Blakley : entity work.blakley
	   port map (
            A   => message  ,
            B       => key      ,
            start_calc  => start_calc_BL ,
            done_calc => done_calc_BL,
            result    => result_BL   ,
            modulus   => modulus  ,
            clk       => clk      ,
            reset_n   => reset_n
	   );	
	
	clk <= not clk after clk_half_period;
	tb1 : process
		begin
		
		
		
            report "********************************************************************************";
			report "TESTING BLAKLEY";
			report "********************************************************************************";
			key <=  std_logic_vector(to_unsigned(20, key'length)); -- e
			--key <= x"0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9"; -- d
			modulus <= x"99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d"; -- n
			message <= std_logic_vector(to_unsigned(1337, message'length));
			reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc_BL <= '1';
			wait until done_calc_BL = '1';
			assert  result_BL = x"6874"
					report "Output message differs from the expected result"
					severity Failure;
			wait for 2 ns;
			
		
--			key <= (others => '0');
--			key <=  std_logic_vector(to_unsigned(20, key'length));
--			message <=  std_logic_vector(to_unsigned(1337, message'length));
--			modulus <=  x"880A504783F52B6837819485374E67256A270C1B74D9779D86DEDA9CE4FE3F33";
--			modulus <= std_logic_vector(to_unsigned(100, modulus'length));
			report "********************************************************************************";
			report "TESTING ENCRYPTION";
			report "********************************************************************************";
			-- RSA_accelerator/testbench/rsa_tests/short_tests/inp_messages/short_test.inp_messages.hex_pt0_in.txt
			-- RSA_accelerator/testbench/rsa_tests/short_tests/otp_messages/short_test.otp_messages.hex_ct0_out.txt
			key <= x"0000000000000000000000000000000000000000000000000000000000010001"; -- e
			--key <= x"0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9"; -- d
			modulus <= x"99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d"; -- n
			message <= x"0a23232323232323232323232323232323232323232323232323232323232323";
			reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc <= '1';
			wait until done_calc = '1';
			assert result = x"85ee722363960779206a2b37cc8b64b5fc12a934473fa0204bbaaf714bc90c01"
					report "Output message differs from the expected result"
					severity Failure;
			wait for 2 ns;
			start_calc <= '0';
			message <= x"0a232020207478742e6e695f307470203a2020202020202020202020454d414e";
            reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc <= '1';
			wait until done_calc = '1';
			assert result = x"08f9baf32e8505cbc9a28fed4d5791dce46508c3d1636232bf91f5d0b6632a9f"
					report "Output message differs from the expected result"
					severity Failure;
			-- Done with encryption test
			-- Starting with decryption test
			start_calc <= '0';
			wait for 2 ns;
			report "********************************************************************************";
			report "TESTING DECRYPTION";
			report "********************************************************************************";
			-- RSA_accelerator/testbench/rsa_tests/short_tests/inp_messages/short_test.inp_messages.hex_ct5_in.txt
			-- RSA_accelerator/testbench/rsa_tests/short_tests/otp_messages/short_test.otp_messages.hex_pt5_out.txt
			key <= x"0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9"; -- d
			modulus <= x"99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d"; -- n
			message <= x"5635ab8cfd7390f2a13bd77238e4dfd2089e0216021806db3b4e8bee2b29c735";
			reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc <= '1';
			assert result = x"2323232323232323232323232323232323232323232323232323232323232323"
					report "Output message differs from the expected result"
					severity Failure;
			wait for 2 ns;
			start_calc <= '0';
			message <= x"85ee722363960779206a2b37cc8b64b5fc12a934473fa0204bbaaf714bc90c01";
			reset_n <= '0', '1' after 2 ns;
			wait for 2 ns;
			start_calc <= '1';
			wait until done_calc = '1';
			assert result = x"0a23232323232323232323232323232323232323232323232323232323232323"
					report "Output message differs from the expected result"
					severity Failure;
			stop;
	end process;



	

end expBehave;
