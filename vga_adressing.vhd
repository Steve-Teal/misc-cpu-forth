library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_addressing is
	port (
		clock        : in std_logic;
		reset        : in std_logic;
		frame_start  : in std_logic;
		load_index   : in std_logic;
		inc_count    : in std_logic;
		vram_data    : in std_logic_vector(15 downto 0);
		vram_mux     : in std_logic_vector(1 downto 0);
		vram_address : out std_logic_vector(11 downto 0);
		chargen_a0   : out std_logic);
end entity;

architecture rtl of vga_addressing is

	signal counter1   : unsigned(5 downto 0);
	signal counter2   : unsigned(3 downto 0);
	signal counter3   : unsigned(7 downto 0);
	signal adder      : unsigned(10 downto 0);
	signal colourchar : std_logic_vector(15 downto 0);
	
begin

	chargen_a0 <= counter2(1);

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' or frame_start = '1' then
				counter1 <= (others=>'0');
				counter2 <= (others=>'0');
				counter3 <= (others=>'0');
			elsif inc_count = '1' then
				if counter1 = "100111" then
					counter1 <= "000000";
					if counter2 = "1111" then
						counter3 <= counter3 + 5;
						counter2 <= "0000";
					else
						counter2 <= counter2 + 1;
					end if;
				else
					counter1 <= counter1 + 1;
				end if;
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			adder(2 downto 0) <= counter1(2 downto 0);
			adder(10 downto 3) <= "00000" & counter1(5 downto 3) + counter3;
		end if;
	end process;
				
	process(clock)
	begin
		if rising_edge(clock) then
			if load_index = '1' then
				colourchar <= vram_data;
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			case vram_mux is
				when "00" => vram_address <= "10" & colourchar(7 downto 0) & std_logic_vector(counter2(3 downto 2));
				when "01" => vram_address <= "01111111" & colourchar(15 downto 12);
				when "10" => vram_address <= "01111111" & colourchar(11 downto 8);
				when "11" => vram_address <= '0' & std_logic_vector(adder);				
				when others => null;
			end case;
		end if;
	end process;
						
end rtl;

-- End of file