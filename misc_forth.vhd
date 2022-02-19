library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity misc_forth is
	port (
		clk12m : in std_logic;
		led    : out std_logic_vector(7 downto 0);
		ain    : inout std_logic_vector(6 downto 0);
		d      : inout std_logic_vector(14 downto 0);
      bdbus  : inout std_logic_vector(1 downto 0));
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
	
	
	
	
	signal cpu_data    : std_logic_vector(15 downto 0);
	signal memory_data : std_logic_vector(15 downto 0);
	signal uart_data   : std_logic_vector(7 downto 0);
	signal data        : std_logic_vector(15 downto 0);
	signal address_reg : std_logic_vector(15 downto 0);
	signal uart_wr     : std_logic;
	signal uart_rd     : std_logic;
	signal address     : std_logic_vector(15 downto 0);
	signal cpu_rd      : std_logic;
	signal cpu_wr      : std_logic;
	signal memory_wr   : std_logic;
	signal led_reg     : std_logic_vector(7 downto 0);
	signal utx         : std_logic;
	signal urx         : std_logic;
	signal data_mux    : std_logic_vector(15 downto 0);
	signal rx_ready    : std_logic;
	signal port_a      : std_logic_vector(6 downto 0);
	signal ddr_a       : std_logic_vector(6 downto 0);
	signal port_d      : std_logic_vector(14 downto 0);
	signal ddr_d       : std_logic_vector(14 downto 0);
	
begin


	
		led <= led_reg;
		
		bdbus(1) <= utx;
		urx <= bdbus(0);
	
l1:	for i in ain'range generate
		begin
			ain(i) <= 'Z' when ddr_a(i) = '0' else port_a(i);
		end generate;

l2:	for i in d'range generate
		begin
			d(i) <= 'Z' when ddr_d(i) = '0' else port_d(i);
		end generate;
		
	
u1:  misc port map (
			clock => clk12m,
			reset => '0',
			data_in => data,
			data_out => cpu_data,
			address => address,
			rd => cpu_rd,
			wr => cpu_wr,
			t1out => open);
			
u2:  memory port map (
			address => address(13 downto 0),
			clock => clk12m,
			data => cpu_data,
			wren => memory_wr,
			q => memory_data);

u3:  uart port map (
			clock => clk12m,
			reset => '0',
			data_in => cpu_data(7 downto 0),
			data_out => uart_data,
			brg => "0000001101000",
			tx_wr => uart_wr,
			tx => utx,
			rx => urx,
			rx_ready => rx_ready,
			rx_rd => uart_rd);
			
	process(clk12m)
	begin
		if rising_edge(clk12m) then
			if cpu_rd = '1' then
				address_reg <= address;
			end if;
		end if;
	end process;
	
	process(clk12m)
	begin
		if rising_edge(clk12m) then
			if cpu_wr = '1' then
				case address is
					when x"7FFB" => port_a <= cpu_data(port_a'range);
					when x"7FFC" => ddr_a <= cpu_data(ddr_a'range);
					when x"7FFD" => port_d <= cpu_data(port_d'range);
					when x"7FFE" => ddr_d <= cpu_data(ddr_d'range);
					when X"7FFF" => led_reg <= cpu_data(led_reg'range);
					when others => null;
				end case;
			end if;
		end if;
	end process;
			
		
	with address_reg select data <=
		(15 downto 1 => '0') & rx_ready when x"FFFF",
		(15 downto 8 => '0') & uart_data when X"FFFE",		
		(15 downto 7 => '0') & ain when X"7FFB",
		(15 downto 7 => '0') & ddr_a when X"7FFC",
		'0' & d when X"7FFD",
		'0' & ddr_d when X"7FFE",
		(15 downto 8 => '0') & led_reg when X"7FFF",
		data_mux when others;
	
	memory_wr <= '1' when cpu_wr = '1' and address(15 downto 14) = "00" else '0';
	uart_wr <= '1' when cpu_wr = '1' and address = X"FFFC" else '0';	

	
	data_mux <= memory_data;
	
	process(clk12m)
	begin
		if rising_edge(clk12m) then
			if cpu_rd = '1' and address = X"FFFE" then
				uart_rd <= '1';
			else
				uart_rd <= '0';
			end if;
		end if;
	end process;
	
end rtl;

-- End of File