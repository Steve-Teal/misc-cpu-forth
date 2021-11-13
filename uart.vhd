library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is

	port (
		clock        : in std_logic;
		reset        : in std_logic;
		data_in      : in std_logic_vector(7 downto 0);
		data_out     : out std_logic_vector(7 downto 0);
		brg          : in std_logic_vector(12 downto 0);
		tx_wr        : in std_logic;
		tx           : out std_logic;
		rx           : in std_logic;
		rx_ready     : out std_logic;
		rx_rd        : in std_logic);
	end entity;

architecture rtl of uart is

	component fifo is
	port (
		clock       : in std_logic ;
		data        : in std_logic_vector (7 downto 0);
		rdreq       : in std_logic ;
		wrreq       : in std_logic ;
		empty       : out std_logic ;
		q       : out std_logic_vector (7 downto 0));
	end component;
	
	signal tx_shift_register   : std_logic_vector(8 downto 0);
	signal shift_tx_shifter    : std_logic;
	signal tx_bit_timer        : unsigned(12 downto 0);
	signal tx_bit_counter      : unsigned(3 downto 0);
	signal tx_running          : std_logic;
	signal tx_bit_timer_top    : std_logic;
	signal tx_bit_counter_zero : std_logic;

	
	signal tx_fifo_rd          : std_logic;
	signal tx_fifo_empty       : std_logic;
	signal tx_fifo_out         : std_logic_vector(7 downto 0);
	signal tx_load_shifter     : std_logic;
	
	
	-- RX --
	
	signal rx_sample      : std_logic;
	signal rx_sync        : std_logic;
	signal rx_bit_timer   : unsigned(12 downto 0);
	signal rx_bit_counter : unsigned(3 downto 0);
	signal rx_shifter     : std_logic_vector(7 downto 0);
	
begin

u1:		fifo port map (
				clock => clock,
				data => data_in,
				rdreq => tx_fifo_rd,
				wrreq => tx_wr,
				empty => tx_fifo_empty,
				q => tx_fifo_out);
			
	tx <= tx_shift_register(0);
	tx_bit_counter_zero <= '1' when tx_bit_counter = "0000" else '0';	
	tx_bit_timer_top <= '1' when tx_bit_timer = unsigned(brg) else '0';
	
	tx_fifo_rd <= not (tx_fifo_empty or tx_running or tx_load_shifter);
	
	
	process(clock)
	begin
		if rising_edge(clock) then
			tx_load_shifter <= tx_fifo_rd;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				tx_shift_register <= (others=>'1');
			elsif tx_load_shifter = '1' then
				tx_shift_register <= tx_fifo_out & '0';
				tx_running <= '1';
			elsif shift_tx_shifter = '1' then
				tx_shift_register <= '1' & tx_shift_register(8 downto 1);
				if tx_bit_counter_zero = '1' then
					tx_running <= '0';
				end if;
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				tx_bit_timer <= (others=>'0');
				shift_tx_shifter <= '0';
			elsif tx_running = '1' then
				if tx_bit_timer_top = '1' then
					tx_bit_timer <= (others=>'0');
					shift_tx_shifter <= '1';
				else
					tx_bit_timer <= tx_bit_timer + 1;
					shift_tx_shifter <= '0';
				end if;		
			else
				shift_tx_shifter <= '0';
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				tx_bit_counter <= "0000";
			elsif tx_load_shifter = '1' then
				tx_bit_counter <= "1010";
			elsif tx_bit_counter_zero = '0' and tx_bit_timer_top = '1' then
				tx_bit_counter <= tx_bit_counter - 1;
			end if;
		end if;
	end process;
	
	------------- RX ------------
	
	rx_sample <= '1' when rx_bit_timer = '0' & unsigned(brg(12 downto 1)) else '0';
	
	process(clock)
	begin
		if rising_edge(clock) then			
			rx_sync <= rx;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				rx_bit_timer <= (others=>'0');
				rx_bit_counter <= (others=>'0');
			elsif rx_sample = '1' and rx_bit_counter = "0000" and rx_sync = '1' then
				rx_bit_timer <= (others=>'0');
				rx_bit_counter <= (others=>'0');
			elsif rx_sample = '1' and rx_bit_counter = "1001" then
				rx_bit_timer <= (others=>'0');
				rx_bit_counter <= (others=>'0');
			elsif rx_bit_timer > 0 or rx_bit_counter > 0 or rx_sync = '0' then
				if rx_bit_timer = unsigned(brg) then
					rx_bit_timer <= (others=>'0');
					rx_bit_counter <= rx_bit_counter + 1;
				else
					rx_bit_timer <= rx_bit_timer + 1;
				end if;
			else
				rx_bit_timer <= (others=>'0');
				rx_bit_counter <= (others=>'0');
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if rx_sample = '1' and rx_bit_counter /= "1001" then
				rx_shifter <= rx_sync & rx_shifter(7 downto 1);
			end if;
		end if;
	end process;
	
	process(clock)
	begin
		if rising_edge(clock) then
			if rx_sample = '1' and rx_bit_counter = "1001" and rx_sync = '1' then
				data_out <= rx_shifter;
				rx_ready <= '0';
			elsif rx_rd = '1' then
				rx_ready <= '1';
			end if;
		end if;
	end process;
	

	
end rtl;