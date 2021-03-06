-- ******************************************************************
-- ******************************************************************
-- ******************************************************************
-- This file is generated by soc_gen and will be overwritten next time
-- the tool is run. See soc_top/README for information on running soc_gen.
-- ******************************************************************
-- ******************************************************************
-- ******************************************************************
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config.all;
use work.clk_config.all;
use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
entity devices is
    port (
        clk_sys : in std_logic;
        cpu0_data_master_ack : in std_logic;
        cpu0_data_master_en : in std_logic;
        cpu0_event_i : out cpu_event_i_t;
        cpu0_event_o : in cpu_event_o_t;
        cpu0_periph_dbus_i : out cpu_data_i_t;
        cpu0_periph_dbus_o : in cpu_data_o_t;
        cpu1_periph_dbus_i : out cpu_data_i_t;
        cpu1_periph_dbus_o : in cpu_data_o_t;
        emac_phy_resetn : out std_logic;
        emac_phy_rx_col : in std_logic;
        emac_phy_rx_crs : in std_logic;
        emac_phy_rx_dv : in std_logic;
        emac_phy_rx_er : in std_logic;
        emac_phy_rxd : in std_logic_vector(3 downto 0);
        emac_phy_tx_en : out std_logic;
        emac_phy_txd : out std_logic_vector(3 downto 0);
        eth_rx_clk : in std_logic;
        eth_tx_clk : in std_logic;
        flash_clk : out std_logic;
        flash_cs : out std_logic_vector(1 downto 0);
        flash_miso : in std_logic;
        flash_mosi : out std_logic;
        pi : in std_logic_vector(31 downto 0);
        po : out std_logic_vector(31 downto 0);
        reset : in std_logic;
        uart0_rx : in std_logic;
        uart0_tx : out std_logic
    );
end;
architecture impl of devices is
    signal rtc_nsec : std_logic_vector(31 downto 0);
    signal rtc_sec : std_logic_vector(63 downto 0);
    type device_t is (NONE, DEV_AIC0, DEV_EMAC, DEV_FLASH, DEV_GPIO, DEV_UART0);
    signal active_dev : device_t;
    type data_bus_i_t is array (device_t'left to device_t'right) of cpu_data_i_t;
    type data_bus_o_t is array (device_t'left to device_t'right) of cpu_data_o_t;
    signal devs_bus_i : data_bus_i_t;
    signal devs_bus_o : data_bus_o_t;
    function decode_address (addr : std_logic_vector(31 downto 0)) return device_t is
    begin
        -- Assumes addr(31 downto 28) = x"a".
        -- Address decoding closer to CPU checks those bits.
        if addr(27 downto 18) = "1011110011" then
            if addr(17 downto 10) = "01000000" then
                if addr(9) = '0' then
                    if addr(8 downto 7) = "00" then
                        if addr(6 downto 4) = "000" then
                            -- ABCD0000-ABCD000F
                            return DEV_GPIO;
                        elsif addr(6 downto 3) = "1000" then
                            -- ABCD0040-ABCD0047
                            return DEV_FLASH;
                        end if;
                    elsif addr(8 downto 4) = "10000" then
                        -- ABCD0100-ABCD010F
                        return DEV_UART0;
                    end if;
                elsif addr(9 downto 6) = "1000" then
                    -- ABCD0200-ABCD023F
                    return DEV_AIC0;
                end if;
            elsif addr(17 downto 13) = "10000" then
                -- ABCE0000-ABCE1FFF
                return DEV_EMAC;
            end if;
        end if;
        return NONE;
    end;
    signal irqs0 : std_logic_vector(7 downto 0) := (others => '0');
begin
    -- Disconnected peripheral buses
    cpu1_periph_dbus_i <= loopback_bus(cpu1_periph_dbus_o);
    -- multiplex data bus to and from devices
    active_dev <= decode_address(cpu0_periph_dbus_o.a);
    cpu0_periph_dbus_i <= devs_bus_i(active_dev);
    bus_split : for dev in device_t'left to device_t'right generate
        devs_bus_o(dev) <= mask_data_o(cpu0_periph_dbus_o, to_bit(dev = active_dev));
    end generate;
    devs_bus_i(NONE) <= loopback_bus(devs_bus_o(NONE));
    -- Instantiate devices
    aic0 : entity work.aic(behav)
        generic map (
            c_busperiod => CFG_CLK_CPU_PERIOD_NS,
            rtc_sec_length34b => TRUE,
            vector_numbers => (x"11", x"12", x"00", x"00", x"15", x"00", x"00", x"00")
        )
        port map (
            back_i => cpu0_data_master_ack,
            bstb_i => cpu0_data_master_en,
            clk_bus => clk_sys,
            db_i => devs_bus_o(DEV_AIC0),
            db_o => devs_bus_i(DEV_AIC0),
            enmi_i => '1',
            event_i => cpu0_event_o,
            event_o => cpu0_event_i,
            irq_i => irqs0,
            reboot => open,
            rst_i => reset,
            rtc_nsec => rtc_nsec,
            rtc_sec => rtc_sec
        );
    emac : entity work.eth_mac(rtl)
        generic map (
            async_bridge_impl2 => FALSE,
            c_addr_width => 11,
            c_buswidth => 32,
            default_mac_addr => x"000000000000"
        )
        port map (
            clk_bus => clk_sys,
            clk_sys => clk_sys,
            db_i => devs_bus_o(DEV_EMAC),
            db_o => devs_bus_i(DEV_EMAC),
            dbsys_i_a => x"00000000",
            dbsys_i_d => x"00000000",
            dbsys_i_en => '0',
            dbsys_i_we => x"0",
            dbsys_i_wr => '0',
            dbsys_o_ack => open,
            dbsys_o_d => open,
            eth_intr => irqs0(0),
            idle => open,
            phy_resetn => emac_phy_resetn,
            phy_rx_clk => eth_rx_clk,
            phy_rx_col => emac_phy_rx_col,
            phy_rx_crs => emac_phy_rx_crs,
            phy_rx_dv => emac_phy_rx_dv,
            phy_rx_er => emac_phy_rx_er,
            phy_rxd => emac_phy_rxd,
            phy_tx_clk => eth_tx_clk,
            phy_tx_en => emac_phy_tx_en,
            phy_tx_er => open,
            phy_txd => emac_phy_txd,
            reset => reset,
            rtc_nsec_i => x"00000000",
            rtc_sec_i => x"0000000000000000"
        );
    flash : entity work.spi2(arch)
        generic map (
            clk_freq => CFG_CLK_CPU_FREQ_HZ,
            num_cs => 2
        )
        port map (
            busy => open,
            clk => clk_sys,
            cpha => '0',
            cpol => '0',
            cs => flash_cs,
            db_i => devs_bus_o(DEV_FLASH),
            db_o => devs_bus_i(DEV_FLASH),
            miso => flash_miso,
            mosi => flash_mosi,
            rst => reset,
            spi_clk => flash_clk
        );
    gpio : entity work.pio(beh)
        port map (
            clk_bus => clk_sys,
            db_i => devs_bus_o(DEV_GPIO),
            db_o => devs_bus_i(DEV_GPIO),
            irq => irqs0(4),
            p_i => pi,
            p_o => po,
            reset => reset
        );
    uart0 : entity work.uartlitedb(arch)
        generic map (
            bps => 115200.0,
            fclk => CFG_CLK_CPU_FREQ_HZ,
            intcfg => 1
        )
        port map (
            clk => clk_sys,
            db_i => devs_bus_o(DEV_UART0),
            db_o => devs_bus_i(DEV_UART0),
            int => irqs0(1),
            rst => reset,
            rx => uart0_rx,
            tx => uart0_tx
        );
end;
