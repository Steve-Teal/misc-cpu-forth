library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_timing is
	port (
		clock         : in std_logic;
		reset         : in std_logic;
		t1            : in std_logic;
		vram_rd       : out std_logic;
		vram_mux      : out std_logic_vector(1 downto 0);
		load_index    : out std_logic;
		load_bitmap   : out std_logic;
		load_colour_0 : out std_logic;
		load_colour_1 : out std_logic;
		start         : out std_logic;
		hsync         : out std_logic;
		vsync         : out std_logic;
		frame_start   : out std_logic);
end entity;

architecture rtl of vga_timing is

	signal hcounter : integer range 0 to 799;
	signal vcounter : integer range 0 to 524;
	signal hcount : unsigned(9 downto 0);
	
	signal vblank : std_logic;
	signal hblank : std_logic;
	

begin

	hcount <= to_unsigned(hcounter,10);
	
	process(clock)
	begin
		if rising_edge(clock) then
			vram_mux <= std_logic_vector(hcount(3 downto 2));
		end if;
	end process;

	--
	-- Horizontal and Vertical counters
	--

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				hcounter <= 0;
				vcounter <= 0;
			else
				if hcounter = 799 then
					if t1 = '1' then
						hcounter <= 0;
						if vcounter = 524 then
							vcounter <= 0;
						else
							vcounter <= vcounter + 1;
						end if;
					end if;
				else
					hcounter <= hcounter + 1;
				end if;
			end if;
		end if;
	end process;
	
	--
	-- Horizontal sync
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			case hcounter is
				when 0 => hsync <= '0';
				when 96 => hsync <= '1';
				when others => null;
			end case;
		end if;
	end process;
	
	--
	-- Horizontal blanking
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			case hcounter is
				when 126 => hblank <= '0';
				when 766 => hblank <= '1';
				when others => null;
			end case;
		end if;
	end process;
	
	--
	-- Vertical sync and blanking 
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			case vcounter is
				when 0 => vsync <= '0';
				when 2 => vsync <= '1';
				when 35 => vblank <= '0';
				when 515 => vblank <= '1';
				when others => null;
			end case;
		end if;
	end process;
	
	
	process(clock)
	begin
		if rising_edge(clock) then 
			if hblank = '0' and vblank = '0' then
				case hcount(3 downto 0) is
					when "0011"|"0111"|"1011"|"1111" =>
						vram_rd <= '1';
						start <= '0';
					when "0000" =>
						vram_rd <= '0';
						load_index <= '1';
					when "0001" =>
						load_index <= '0';
					when "0100" =>
						vram_rd <= '0';
						load_bitmap <= '1';
					when "0101" =>
						load_bitmap <= '0';
					when "1000" =>
						vram_rd <= '0';
						load_colour_0 <= '1';
					when "1001" =>
						load_colour_0 <= '0';
					when "1100" =>
						vram_rd <= '0';
						load_colour_1 <= '1';
					when "1101" =>
						load_colour_1 <= '0';
					when "1110" =>
						start <= '1';
					when others => null;
				end case;
			else
				vram_rd <= '0';
				load_index <= '0';
				load_bitmap <= '0';
				load_colour_0 <= '0';
				load_colour_1 <= '0';
				start <= '0';
			end if;
		end if;
	end process;
	
	--
	-- Frame start - pulse at start of each frame to reset address counters
	--
	
	process(clock)
	begin
		if rising_edge(clock) then
			if hcounter = 0 and vcounter = 0 then
				frame_start <= '1';
			else
				frame_start <= '0';
			end if;
		end if;
	end process;
						

end rtl;

-- End of file 