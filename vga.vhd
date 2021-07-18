library ieee;
use ieee.std_logic_1164.all;

entity vga is
	port (
		clock         : in std_logic;
		reset         : in std_logic;
		t1            : in std_logic;
		hsync         : out std_logic;
		vsync         : out std_logic;
		vram_data     : in std_logic_vector(15 downto 0);
		vram_address  : out std_logic_vector(11 downto 0);
		vram_rd       : out std_logic;
		red           : out std_logic_vector(3 downto 0);
		green         : out std_logic_vector(3 downto 0);
		blue          : out std_logic_vector(3 downto 0));
end entity;

architecture rtl of vga is

	component vga_serializer is
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
	end component;

	component vga_timing is
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
	end component;
	
	component vga_addressing is
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
	end component;
	
	signal start : std_logic;
	signal load_index : std_logic;
	signal load_bitmap : std_logic;
	signal load_colour_0 : std_logic;
	signal load_colour_1 : std_logic;
	signal frame_start : std_logic;
	signal char_gen_a0 : std_logic;
	signal vram_mux : std_logic_vector(1 downto 0);

begin

u1:	vga_serializer port map (
		clock => clock,
		reset => reset,
		vram_data_in => vram_data,
		load_colour_0 => load_colour_0,
		load_colour_1 => load_colour_1,
		load_bitmap => load_bitmap,
		a0 => char_gen_a0,
		start => start,
		red => red,
		green => green,
		blue => blue);
		
u2: vga_timing port map (
		clock => clock,
		reset => reset,
		t1 => t1,
		vram_rd => vram_rd,
		vram_mux => vram_mux,
		load_index => load_index,
		load_bitmap => load_bitmap,
		load_colour_0 => load_colour_0,
		load_colour_1 => load_colour_1,
		start => start,
		hsync => hsync,
		vsync => vsync,
		frame_start => frame_start);
		
u3: vga_addressing port map (
		clock => clock,
		reset => reset,
		frame_start => frame_start,
		load_index => load_index,
		inc_count => load_bitmap,
		vram_data => vram_data,
		vram_mux => vram_mux,
		vram_address => vram_address,
		chargen_a0 => char_gen_a0);

end rtl;

-- End of file