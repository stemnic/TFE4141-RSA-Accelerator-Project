library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity blakley is
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
end blakley;


architecture modmult of blakley is
    TYPE State_type IS (idle, shift_prod, sub_once, sub, done);  -- Define the states
	SIGNAL State : State_Type;    -- Create a signal that uses 
    shared variable index : integer;
    shared variable tmp : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    shared variable sub_count : integer;
begin
    PROCESS (clk, reset_n) 
    BEGIN 
	If (reset_n = '0') THEN 
	State <= idle;
 
    ELSIF rising_edge(clk) THEN    -- if there is a rising edge of the
			 -- clock, then do the stuff below
 
	-- The CASE statement checks the value of the State variable,
	-- and based on the value and any other control signals, changes
	-- to a new state.
    CASE State IS
    

        WHEN idle => 
        result <= (others => '0'); -- Reset the result
        index := 0;
        done_calc <= '0';
        IF (start_calc = '1') THEN
            State <= shift_prod;
        END IF;

        WHEN shift_prod => 
            index := index + 1;
            IF index = C_block_size THEN -- Done calc 
                State <= done;
            ELSE
                IF message(index) = '1' THEN 
                    result(C_block_size -1 downto 0) <= (result(C_block_size -1 downto 0) & '0' ) + (key); -- No need to shift key?
                ELSE
                    result(C_block_size-1 downto 0) <= (result(C_block_size -1 downto 0) & '0' );
                END IF; 
                State <= sub;
            END IF;
 
        WHEN sub => 
            sub_count := sub_count +1;
            IF sub_count = 3 THEN
                sub_count := 0;
                State <= shift_prod;
            ELSE
                tmp := result - modulus; 
                IF tmp(C_block_size-1) = '0' THEN
                    result <= tmp;
                    State <= sub_once;
                END IF; 
            END IF;
		
        WHEN done=> 
        done_calc <= '1'; 

        WHEN others=>
        State <= idle;

	END CASE; 
    END IF;
    END PROCESS;
end modmult;