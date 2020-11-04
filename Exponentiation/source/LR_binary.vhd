library ieee; 
use ieee.std_logic_1164.all; 
-- use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity LR_binary is
	generic (
		C_block_size : integer := 256
	);
	port (
		--input controll
        start_calc	: in STD_LOGIC;

		--input data
		message 	: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		key 		: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

		--ouput controll
		done_calc	: out STD_LOGIC;

		--output data
		result 		: out STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--modulus
		modulus 	: in STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end LR_binary;


architecture expmod of LR_binary is
	shared variable index : integer range -1 to 256;
	TYPE State_type IS (idle, exponentiate, find_first_bit, done);  -- Define the states
	SIGNAL State : State_Type; 
	shared variable C : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
	shared variable started : integer range 0 to 1;



	blakley_one : entity work.blakley
		port map ( 
			message   => A  ,
			key       => B      ,
			start_calc  => start_calc ,
			done_calc => done_calc,
			result    => result   ,
			modulus   => modulus  ,
			clk       => clk      ,
			reset_n   => reset_n
		)


begin Process (clk, reset_n)
begin 
IF (reset_n = '0) then
	result <= (others => '0');
	index := C_blokck_size;
	done_calc <= '0';
ELSE
	Case State IS

	when idle =>
	result <= (others => '0'); -- Reset the result
	done_calc <= '0';
	tmp := (others => '0');
	IF (start_calc = '1') THEN
		index := 255; -- Wastes time?
		State <= running;
	END IF;

	when find_first_bit =>
		if message(index) = '1' then
			C <= message;
			State <= exponentiate;
		else
			index := index -1;

	when first_exponentiate =>
		if done_calc = '0' and started = 0 then
			index := index -1;
			-- Do C*C mod N.
			-- Set A=B=C
			start_calc_one <= 1;
			started := 1;
		elsif done_calc = '1' and started = 1 then
			started := 0;
			if message(index) = '1' then
				State <= second_expontiate;
			else 
				State <= first_exponentiate;
		end if;

	when second_exponentiate =>
		if done_calc = '0' amd started = 0 then
			-- Set A = C, B = M
			-- Do C*M mod N.
			start_calc_one <= 1;
		elsif done_calc = '1' and started = 1 then

			start_calc <= '0'
		end if;

	when others=>
		State =>  idle;
	

	end case;
	end if;
		
end Process;

end expmod;
