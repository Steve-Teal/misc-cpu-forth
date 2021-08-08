library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity misc_forth is
	port (
		clk12m     : in std_logic;
		led      : out std_logic_vector(7 downto 0);
		ain      : inout std_logic_vector(6 downto 0);
		d        : inout std_logic_vector(14 downto 0);
		pio : inout std_logic_vector(8 downto 1);
      user_btn   : in std_logic;
      bdbus      : inout std_logic_vector(1 downto 0));
end misc_forth;

architecture rtl of misc_forth is

	component misc is
		port (
			clock    : in std_logic;
			reset    : in std_logic;
			data_in  : in std_logic_vector(15 downto 0);
			data_out : out std_logic_vector(15 downto 0);
			address  : out std_logic_vector(15 downto 0);
			rd       : out std_logic;
			wr       : out std_logic;
			t1out    : out std_logic);
	end component;

	component memory is
		 port
		 (
			address  : in std_logic_vector (13 downto 0);
			clock    : in std_logic;
			data     : in std_logic_vector (15 downto 0);
			wren     : in std_logic;
			q        : out std_logic_vector (15 downto 0)
		 );
	end component;
	
	component uart is
		 port (
			clock    : in std_logic;
			reset    : in std_logic;
			data_in  : in std_logic_vector(7 downto 0);
			data_out : out std_logic_vector(7 downto 0);
			brg      : in std_logic_vector(12 downto 0);
			tx_wr    : in std_logic;
			tx       : out std_logic;
			rx       : in std_logic;
			rx_ready : out std_logic;
			rx_rd    : in std_logic);
	end component;
	
	component pll is
		port (
		inclk0		: in std_logic := '0';
		c0		      : out std_logic);
	end component;
	
	component vga is
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
	end component;
	
	component vram is
		port (
		address	: in std_logic_vector (11 downto 0);
		clock		: in std_logic;
		data		: in std_logic_vector (15 downto 0);
		wren		: in std_logic;
		q		   : out std_logic_vector (15 DOWNTO 0));
	end component;
	
	signal reset : std_logic;
	
	signal cpu_data : std_logic_vector(15 downto 0);
	signal memory_data : std_logic_vector(15 downto 0);
	signal uart_data : std_logic_vector(7 downto 0);
	signal data : std_logic_vector(15 downto 0);
	signal address_reg : std_logic_vector(15 downto 0);
	
	signal uart_wr : std_logic;
	signal uart_rd : std_logic;

	
	signal address : std_logic_vector(15 downto 0);
	
	signal cpu_rd : std_logic;
	signal cpu_wr : std_logic;
	
	signal memory_wr : std_logic;
	
	signal led_reg : std_logic_vector(7 downto 0);
	
	signal clock : std_logic;
	signal utx : std_logic;
	signal urx : std_logic;
	
	signal t1 : std_logic;
	signal hsync : std_logic;
	signal vsync : std_logic;
	signal vram_data : std_logic_vector(15 downto 0);
	signal vram_address : std_logic_vector(11 downto 0);
	signal vram_rd : std_logic;
	signal vram_wr : std_logic;
	signal red : std_logic_vector(3 downto 0);
	signal green : std_logic_vector(3 downto 0);
	signal blue : std_logic_vector(3 downto 0);
	signal vram_address_mux : std_logic_vector(11 downto 0);
	signal data_mux : std_logic_vector(15 downto 0);
	signal mscounter : unsigned(15 downto 0);
	
	signal hfcounter : integer range 0 to 25199;
	
begin

	pio(4) <= vsync;
	ain(0) <= hsync;
	ain(4 downto 1) <= blue;
	ain(6 downto 5) <= green(1 downto 0);
	d(1 downto 0) <= green(3 downto 2);
	d(5 downto 2) <=  red;
	d(14 downto 6) <= (others=>'Z');
	


	reset <= '0'; --not user_btn;
	led <= led_reg;
	
	pio(3) <= '1';
	
	--bdbus(1) <= utx;
	--urx <= bdbus(0);
	
	pio(2) <= utx;
	urx <= pio(1);
	
u1:  misc port map (
			clock => clock,
			reset => reset,
			data_in => data,
			data_out => cpu_data,
			address => address,
			rd => cpu_rd,
			wr => cpu_wr,
			t1out => t1);
			
u2:  memory port map (
			address => address(13 downto 0),
			clock => clock,
			data => cpu_data,
			wren => memory_wr,
			q => memory_data);

u3:  uart port map (
			clock => clock,
			reset => reset,
			data_in => cpu_data(7 downto 0),
			data_out => uart_data,
			brg => "0000011011010",
			tx_wr => uart_wr,
			tx => utx,
			rx => urx,
			rx_ready => open,
			rx_rd => uart_rd);
			
u4:  pll port map (
			inclk0 => clk12m,
			c0 => clock);
			
u5:  vga port map (
			clock => clock,
			reset => reset,
			t1 => t1,
			hsync => hsync,
			vsync => vsync,
			vram_data => vram_data,
			vram_address => vram_address,
			vram_rd => vram_rd,
			red => red,
			green => green,
			blue => blue);
			
u6: 	vram port map (
			address => vram_address_mux,
			clock => clock,
			data => cpu_data,
			wren => vram_wr,
			q => vram_data);
			
	process(clock)
	begin
		if rising_edge(clock) then
			if cpu_rd = '1' then
				address_reg <= address;
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if cpu_wr = '1' and address = X"7FFF" then
				led_reg <= cpu_data(7 downto 0);
			end if;
		end if;
	end process;
			
		
	with address_reg select data <=
		(15 downto 8 => '0') & uart_data when X"FFFE",		
		(15 downto 8 => '0') & led_reg when X"7FFF",
		std_logic_vector(mscounter) when X"7FFD",
		data_mux when others;
	
	memory_wr <= '1' when cpu_wr = '1' and address(15 downto 14) = "00" else '0';
	uart_wr <= '1' when cpu_wr = '1' and address = X"FFFC" else '0';
	--uart_rd <= '1' when cpu_rd = '1' and address_reg = X"FFFE" else '0';
	vram_address_mux <= vram_address when vram_rd = '1' else address(11 downto 0);
	
	vram_wr <= '1' when cpu_wr = '1' and address(15 downto 12) = "0100" else '0';
	
	data_mux <= memory_data when address_reg(15 downto 14) = "00" else vram_data;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if cpu_rd = '1' and address = X"FFFE" then
				uart_rd <= '1';
			else
				uart_rd <= '0';
			end if;
		end if;
	end process;
	
	
	process(clock)
	begin
		if rising_edge(clock) then
			if hfcounter = 25199 then
				hfcounter <= 0;
				mscounter <= mscounter + 1;
			else
				hfcounter <= hfcounter + 1;
			end if;
		end if;
	end process;
		

end rtl;

-- End of File