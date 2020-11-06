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
        start_calc	: in STD_LOGIC := '0';

		--input data
		message 	: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		key 		: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

		--ouput controll
		done_calc_LR	: out STD_LOGIC;
		

		--output data
		result_LR 		: out STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--modulus
		modulus 	: in STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end LR_binary;


architecture expmod of LR_binary is
	shared variable index : integer range -1 to 256;
	signal d_index : std_logic_vector(9 downto 0);
	TYPE State_type IS (idle, first_exponentiate, second_exponentiate, find_first_bit, done);  -- Define the states
	SIGNAL State : State_Type; 
	signal C : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal M 		: STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
    signal result_blakley 		: STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
	shared variable started : integer range 0 to 1;
	signal start_blakley : std_logic;
	signal done_calc_blakley : std_logic;

begin

	blakley_one : entity work.blakley
		port map ( 
			A          => M ,
			B          => C ,
			start_calc => start_blakley ,
			done_calc  => done_calc_blakley ,
			result     => result_blakley ,
			modulus    => modulus ,
			clk        => clk ,
			reset_n    => reset_n
		);

 
process (clk, reset_n)
begin 
IF (reset_n = '0') then
	result_LR <= (others => '0');
	index := C_block_size-1;
	done_calc_LR <= '0';
	State <= idle;
ELSE
    d_index <= std_logic_vector(to_unsigned(index, d_index'length));
	Case State IS

	when idle =>
	--result <= (others => '0'); -- Reset the result
	done_calc_LR <= '0';
	C <= (others => '0');
	IF (start_calc = '1') THEN
		index := 255; -- Wastes time?
		State <= first_exponentiate;
		result_LR <= (others => '0');
		C(0) <= '1';
		M <= (others => '0');
		start_blakley <= '0';
        started := 0;

	END IF;

	when find_first_bit =>
		if message(index) = '1' then
			C <= message;
			State <= first_exponentiate;
		else
			index := index -1;
		end if;

	when first_exponentiate =>
	    if index = -1 then
	       State <= done;
	    else
            if done_calc_blakley = '0' and started = 0 then
                index := index -1;
                -- Do C*C mod N.
                -- Set A=B=C
                M <= C;
                start_blakley <= '1';
                started := 1;
            elsif done_calc_blakley = '1' and started = 1 then
                started := 0;
                start_blakley <= '1';
                C <= result_blakley;
                if key(index) = '1' then
                    State <= second_exponentiate;
                else 
                    State <= first_exponentiate;
              end if;
            end if;
         end if;

	when second_exponentiate =>
		if done_calc_blakley = '0' and started = 0 then
			-- Set A = C, B = M
			-- Do C*M mod N.
			M <= message;
			start_blakley <= '1';
			started := 1;
		elsif done_calc_blakley = '1' and started = 1 then
		      started := 0;
		      C <= result_blakley;
			  start_blakley <= '0';
			  State <= first_exponentiate;
		end if;
		
	when done=>
	   result_LR <= C;
	   done_calc_LR <= '1';
	   State <= idle;
	   
	when others =>
		State <=  idle;
	
	end case;
	end if;
		
end Process;

end expmod;
