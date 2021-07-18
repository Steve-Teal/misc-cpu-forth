library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_serializer is
	port (
		clock         : in std_logic;
		reset         : in std_logic;
		vram_data_in  : in std_logic_vector(15 downto 0);
		load_colour_0 : in std_logic;
		load_colour_1 : in std_logic;
		load_bitmap   : in std_logic;
		a0            : in std_logic;
		start         : in std_logic;
		red           : out std_logic_vector(3 downto 0);
		green         : out std_logic_vector(3 downto 0);
		blue          : out std_logic_vector(3 downto 0));
end entity;

architecture rtl of vga_serializer is

	signal colour_0_hold : std_logic_vector(11 downto 0);
	signal colour_1_hold : std_logic_vector(11 downto 0);
	signal bitmap_hold   : std_logic_vector(7 downto 0);
	
	signal colour_0       : std_logic_vector(11 downto 0);
	signal colour_1       : std_logic_vector(11 downto 0);
	signal shift_register : std_logic_vector(7 downto 0);
	
	signal blanking       : std_logic;
	signal shift_enable   : std_logic;
	
	signal counter : unsigned(3 downto 0);
	
begin
	--
	-- Holding registers
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if load_colour_0 = '1' then
				colour_0_hold <= vram_data_in(11 downto 0);
			end if;
			if load_colour_1 = '1' then
				colour_1_hold <= vram_data_in(11 downto 0);
			end if;
			if load_bitmap = '1' then
				if a0 = '1' then
					bitmap_hold <= vram_data_in(7 downto 0);
				else
					bitmap_hold <= vram_data_in(15 downto 8);
				end if;
			end if;
		end if;
	end process;
	
	--
	-- Shift register
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if start = '1' then
				shift_register <= bitmap_hold;
				colour_0 <= colour_0_hold;
				colour_1 <= colour_1_hold;
			elsif shift_enable = '1' then
				shift_register <= shift_register(6 downto 0) & '0';
			end if;
		end if;
	end process;
	
	--
	-- Output register
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if blanking = '1' then
				red <= "0000";
				green <= "0000";
				blue <= "0000";
			else
				if shift_register(7) = '0' then
					red <= colour_0(3 downto 0);
					green <= colour_0(7 downto 4);
					blue <= colour_0(11 downto 8);
				else
					red <= colour_1(3 downto 0);
					green <= colour_1(7 downto 4);
					blue <= colour_1(11 downto 8);
				end if;
			end if;
		end if;
	end process;
	
	--
	-- Blanking
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				blanking <= '1';
			elsif start = '1' then
				blanking <= '0';
			elsif counter = "1111" then
				blanking <= '1';
			end if;
		end if;
	end process;
	
	--
	-- Control counter
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' or start = '1' then
				counter <= "0000";
			elsif blanking = '0' then
				counter <= counter + 1;
			end if;
		end if;
	end process;
				
	shift_enable <= counter(0);
				
end rtl;

-- End of file

