# OLED
set_property PACKAGE_PIN U10 [get_ports oled_dc_n]
set_property PACKAGE_PIN U9 [get_ports oled_reset_n]
set_property PACKAGE_PIN AB12 [get_ports oled_spi_clk]
set_property PACKAGE_PIN AA12 [get_ports oled_spi_data]
set_property PACKAGE_PIN U11 [get_ports oled_vbat]
set_property PACKAGE_PIN U12 [get_ports oled_vdd]
set_property IOSTANDARD LVCMOS33 [get_ports {oled_dc_n oled_reset_n oled_spi_clk oled_spi_data oled_vbat oled_vdd}]

# Slide Switches
set_property PACKAGE_PIN F22 [get_ports {prog_select[0]}]
set_property PACKAGE_PIN G22 [get_ports {prog_select[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {prog_select[*]}]

# LEDS
set_property PACKAGE_PIN T22 [get_ports {prog_leds[0]}]
set_property PACKAGE_PIN T21 [get_ports {prog_leds[1]}]
set_property PACKAGE_PIN U14 [get_ports led_resume]
set_property IOSTANDARD LVCMOS25 [get_ports {led_resume prog_leds[*]}]

# Buttons
set_property PACKAGE_PIN P16 [get_ports reset]
set_property PACKAGE_PIN R18 [get_ports btn_resume]
set_property IOSTANDARD LVCMOS25 [get_ports {btn_resume reset}]

# Clock
set_property PACKAGE_PIN Y9 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]
create_clock -period 10.000 -name clock -waveform {0.000 5.000} clock

# Keypad - Pmod JA Top Row (Inputs: Rows)
set_property PACKAGE_PIN Y11  [get_ports {key_row[0]}]
set_property PACKAGE_PIN AA11 [get_ports {key_row[1]}]
set_property PACKAGE_PIN Y10  [get_ports {key_row[2]}]
set_property PACKAGE_PIN AA9  [get_ports {key_row[3]}]

# Keypad - Pmod JA Bottom Row (Outputs: Columns)
set_property PACKAGE_PIN AB11 [get_ports {key_col[0]}]
set_property PACKAGE_PIN AB10 [get_ports {key_col[1]}]
set_property PACKAGE_PIN AB9  [get_ports {key_col[2]}]
set_property PACKAGE_PIN AA8  [get_ports {key_col[3]}]

# Shared Properties
set_property IOSTANDARD LVCMOS33 [get_ports {key_row[*] key_col[*]}]
set_property PULLDOWN true [get_ports {key_row[*]}]