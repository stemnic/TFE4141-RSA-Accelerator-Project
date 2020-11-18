library ieee; 
use ieee.std_logic_1164.all; 
-- use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity exponentiation is
	generic (
		C_block_size : integer := 256
	);
	port (
		--input controll
		valid_in	: in STD_LOGIC;
		ready_in	: out STD_LOGIC;

		--input data
		message 	: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		key 		: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		msgin_last : in std_logic; 

		--ouput controll
		ready_out	: in STD_LOGIC;
		valid_out	: out STD_LOGIC;
        msgout_last : out std_logic; -- Core


		--output data
		result 		: out STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--modulus
		modulus 	: in STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end exponentiation;


architecture expBehave of exponentiation is -- Using LR_binary
	signal d_index          : std_logic_vector(9 downto 0); -- For debugging
	TYPE State_type IS (idle, first_exponentiate, second_exponentiate, find_first_bit, done);  -- Define the states
	SIGNAL State            : State_Type; 
	signal C                : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal M 		        : STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
	shared variable index   : integer range -1 to 256; 
    signal result_blakley   : STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
    signal M_reg : STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
    signal K_reg : STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

    
	shared variable started : integer range 0 to 1;
	signal start_blakley    : std_logic;
	signal done_calc_blakley: std_logic;

begin

	blakley : entity work.blakley
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
	result <= (others => '0');
	index := C_block_size-1;
	ready_in <= '1';
	valid_out <= '0';
	State <= idle;
ELSE
    d_index <= std_logic_vector(to_unsigned(index, d_index'length)); -- For debugging
	Case State IS

	when idle =>
        C <= (others => '0');
        M_reg <= (others => '0');
        ready_in <= '1';
		IF (valid_in = '1') and falling_edge(clk) THEN
			--result <= (others => '0');
			msgout_last <= msgin_last;
		    valid_out <= '0';
			index := 255;
			K_reg <= key;
			M_reg <= message;
			C <= message;
			start_blakley <= '0';
			started := 0;
			State <= find_first_bit;
	   END IF;

	when find_first_bit =>
        ready_in <= '0';
		if K_reg(index) = '1' then
			State <= first_exponentiate;
		else
			index := index -1;
		end if;

	when first_exponentiate =>
	   
        if done_calc_blakley = '0' and started = 0 then
            -- Do C*C mod N.
            -- Set A=B=C
             index := index -1;
             if index = -1 then
               State <= done;
             else
                M <= C;
                start_blakley <= '1';
                started := 1;
             end if;
            
        elsif done_calc_blakley = '1' and started = 1 then
            started := 0;
            start_blakley <= '0';
            C <= result_blakley;
            if K_reg(index) = '1' then
                State <= second_exponentiate;
            else 
                State <= first_exponentiate;
          end if;
        end if;

	when second_exponentiate =>
		if done_calc_blakley = '0' and started = 0 then
			-- Set A = C, B = M
			-- Do C*M mod N.
			M <= M_reg;
			start_blakley <= '1';
			started := 1;
		elsif done_calc_blakley = '1' and started = 1 then
		      started := 0;
		      C <= result_blakley;
			  start_blakley <= '0';
			  State <= first_exponentiate;
		end if;
		
	when done=>
		valid_out <= '1';
        result <= C;
		if ready_out = '1' then
			State <= idle;
		end if;

	   
	when others =>
		State <= idle;
	
	end case;
	end if;
		
end Process;

end expBehave;
