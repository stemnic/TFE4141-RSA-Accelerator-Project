library ieee; 
use ieee.std_logic_1164.all; 
-- use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity blakley is
	generic (
		C_block_size : integer := 256
	);
	port (
		--input controll
        start_calc	: in STD_LOGIC;

		--input data
		A 	        : in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		B 	        : in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

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
    TYPE State_type IS (idle, find_first_bit, shift_prod, sub_once, sub, done);  -- Define the states
	SIGNAL State : State_Type; 
    shared variable index : integer range -1 to 256;
    shared variable tmp : STD_LOGIC_VECTOR(C_block_size+1 downto 0);
    shared variable sub_count : integer range 0 to 3;

begin
    PROCESS (clk, reset_n) 
    BEGIN 
	If (reset_n = '0') THEN 
        State <= idle;
        result <= (others => '0'); -- Reset the result
        index := C_block_size-1;
        done_calc <= '0';
 
    ELSIF falling_edge(clk) THEN 
 
    CASE State IS 
    

        WHEN idle => 
            result <= (others => '0'); -- Reset the result
            done_calc <= '0';
            IF (start_calc = '1') THEN
                tmp := (others => '0');
                index := C_block_size-1;
                State <= find_first_bit;
                -- Make modulus *2?
        END IF;
        
        when find_first_bit =>
            IF index = -1 THEN 
                State <= done; --edge case
            ELSE         
                IF A(index) = '1' THEN 
                    State <= shift_prod;
                ELSE  
                    index := index - 1;
                END IF;
           END IF;

        WHEN shift_prod => 
            IF index = -1 THEN -- Done calc 
                State <= done;
            ELSE         
                IF A(index) = '1' THEN 
                    tmp(C_block_size+1 downto 0) := std_logic_vector(shift_left(unsigned(tmp), 1) + unsigned(B));  
                ELSE
                    tmp(C_block_size+1 downto 0) := std_logic_vector(shift_left(unsigned(tmp), 1));
                END IF; 
                index := index - 1;
                State <= sub;
           END IF;
 
        WHEN sub => 
            sub_count := sub_count + 1;

            IF sub_count = 3 THEN -- Do subtraction at most twice
                sub_count := 0;
                State <= shift_prod;
            ELSE
                IF (tmp >= modulus) THEN
                        tmp := STD_LOGIC_VECTOR(tmp - modulus);
                END IF;
            END IF; 

		
        WHEN done=> 
            done_calc <= '1';
            State <= idle; 
            result <= tmp(C_block_size-1 downto 0);

        WHEN others=>
            State <= idle;

	END CASE; 
    END IF;
    END PROCESS;
end modmult;