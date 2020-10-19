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
    shared variable index : integer range 0 to 256;
    shared variable tmp : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    shared variable sub_count : integer range 0 to 3;



function finding_first_one (signal a : std_logic_vector(C_block_size-1 downto 0)) return integer is -- Doesn't work :(
    begin    
        for i in a'high to a'low loop
            if a(i) = '1' then
                return i;
            end if;
        end loop;    
        -- all zero
        return 0;
    end function;

begin
    PROCESS (clk, reset_n) 
    BEGIN 
	If (reset_n = '0') THEN 
    State <= idle;
    result <= (others => '0'); -- Reset the result
    index := C_block_size;
    done_calc <= '0';
 
    ELSIF rising_edge(clk) THEN    -- if there is a rising edge of the
			 -- clock, then do the stuff below
 
    CASE State IS
    

        WHEN idle => 
        result <= (others => '0'); -- Reset the result
        done_calc <= '0';
        tmp := (others => '0');
        IF (start_calc = '1') THEN
--            index := finding_first_one(message); -- Start at MSB
            index := 255; -- Wastes time?
            State <= shift_prod;
        END IF;
                

        WHEN shift_prod => 
           
            IF message(index) = '1' THEN 
                result(C_block_size -1 downto 0) <= std_logic_vector(shift_left(unsigned(result), 1) + unsigned(key)); 
            ELSE
                result(C_block_size-1 downto 0) <= std_logic_vector(shift_left(unsigned(result), 1));
            END IF; 
            
            State <= sub;
            IF index = 0 THEN -- Done calc 
                State <= done;
            END IF;

            index := index - 1;
 
        WHEN sub => 
            sub_count := sub_count + 1;
            IF sub_count = 3 THEN
                sub_count := 0;
                State <= shift_prod;
                -- TODO: dette funker ikke
--            ELSE
--                tmp := STD_LOGIC_VECTOR(result - modulus); 
--                IF tmp(C_block_size-1) = '0' THEN
--                    result <= tmp;
--                END IF; 
            END IF;
		
        WHEN done=> 
        done_calc <= '1'; 

        WHEN others=>
        State <= idle;

	END CASE; 
    END IF;
    END PROCESS;
end modmult;