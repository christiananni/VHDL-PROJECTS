# pmod I2S2 connected to JB
set_property IOSTANDARD LVCMOS33 [get_ports rx_lrck_0]
set_property IOSTANDARD LVCMOS33 [get_ports rx_mclk_0]
set_property IOSTANDARD LVCMOS33 [get_ports rx_sclk_0]
set_property IOSTANDARD LVCMOS33 [get_ports rx_sdin_0]
set_property IOSTANDARD LVCMOS33 [get_ports tx_lrck_0]
set_property IOSTANDARD LVCMOS33 [get_ports tx_mclk_0]
set_property IOSTANDARD LVCMOS33 [get_ports tx_sclk_0]
set_property IOSTANDARD LVCMOS33 [get_ports tx_sdout_0]
set_property PACKAGE_PIN A14 [get_ports tx_mclk_0]
set_property PACKAGE_PIN A16 [get_ports tx_lrck_0]
set_property PACKAGE_PIN B15 [get_ports tx_sclk_0]
set_property PACKAGE_PIN B16 [get_ports tx_sdout_0]
set_property PACKAGE_PIN A15 [get_ports rx_mclk_0]
set_property PACKAGE_PIN A17 [get_ports rx_lrck_0]
set_property PACKAGE_PIN C15 [get_ports rx_sclk_0]
set_property PACKAGE_PIN C16 [get_ports rx_sdin_0]

# SPI connected to JA, top row
set_property PACKAGE_PIN J1 [get_ports SPI_M_0_ss_io]
set_property PACKAGE_PIN G2 [get_ports SPI_M_0_sck_io]
set_property PACKAGE_PIN L2 [get_ports SPI_M_0_io0_io]
set_property PACKAGE_PIN J2 [get_ports SPI_M_0_io1_io]
set_property IOSTANDARD LVCMOS33 [get_ports SPI_M_0_io0_io]
set_property IOSTANDARD LVCMOS33 [get_ports SPI_M_0_io1_io]
set_property IOSTANDARD LVCMOS33 [get_ports SPI_M_0_sck_io]
set_property IOSTANDARD LVCMOS33 [get_ports SPI_M_0_ss_io]

# Button
set_property IOSTANDARD LVCMOS33 [get_ports effect]
set_property PACKAGE_PIN T18 [get_ports effect]

# Switch
set_property IOSTANDARD LVCMOS33 [get_ports lfo_enable]
set_property PACKAGE_PIN V17 [get_ports lfo_enable]

# LEDs
set_property PACKAGE_PIN U16 [get_ports {LED[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[0]}]
set_property PACKAGE_PIN E19 [get_ports {LED[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[1]}]
set_property PACKAGE_PIN U19 [get_ports {LED[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[2]}]
set_property PACKAGE_PIN V19 [get_ports {LED[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[3]}]
set_property PACKAGE_PIN W18 [get_ports {LED[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[4]}]
set_property PACKAGE_PIN U15 [get_ports {LED[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[5]}]
set_property PACKAGE_PIN U14 [get_ports {LED[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[6]}]
set_property PACKAGE_PIN V14 [get_ports {LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[7]}]
set_property PACKAGE_PIN V13 [get_ports {LED[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[8]}]
set_property PACKAGE_PIN V3 [get_ports {LED[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[9]}]
set_property PACKAGE_PIN W3 [get_ports {LED[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[10]}]
set_property PACKAGE_PIN U3 [get_ports {LED[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[11]}]
set_property PACKAGE_PIN P3 [get_ports {LED[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[12]}]
set_property PACKAGE_PIN N3 [get_ports {LED[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[13]}]
set_property PACKAGE_PIN P1 [get_ports {LED[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[14]}]
set_property PACKAGE_PIN L1 [get_ports {LED[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[15]}]





















