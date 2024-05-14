$date
	Tue May 14 14:49:24 2024
$end
$version
	Icarus Verilog
$end
$timescale
	1ps
$end
$scope module rx_hash $end
$var wire 1 ! clk $end
$var wire 320 " hash_key [319:0] $end
$var wire 32 # m_axis_hash [31:0] $end
$var wire 4 $ m_axis_hash_type [3:0] $end
$var wire 1 % m_axis_hash_valid $end
$var wire 1 & rst $end
$var wire 64 ' s_axis_tdata [63:0] $end
$var wire 8 ( s_axis_tkeep [7:0] $end
$var wire 1 ) s_axis_tlast $end
$var wire 1 * s_axis_tvalid $end
$var wire 32 + hash_part_ipv4_port [31:0] $end
$var wire 32 , hash_part_ipv4_ip [31:0] $end
$var parameter 34 - CYCLE_COUNT $end
$var parameter 32 . DATA_WIDTH $end
$var parameter 32 / KEEP_WIDTH $end
$var parameter 32 0 PTR_WIDTH $end
$var reg 1 1 active_next $end
$var reg 1 2 active_reg $end
$var reg 16 3 eth_type_next [15:0] $end
$var reg 16 4 eth_type_reg [15:0] $end
$var reg 1 5 hash_data_ipv4_next $end
$var reg 1 6 hash_data_ipv4_reg $end
$var reg 288 7 hash_data_next [287:0] $end
$var reg 288 8 hash_data_reg [287:0] $end
$var reg 1 9 hash_data_tcp_next $end
$var reg 1 : hash_data_tcp_reg $end
$var reg 4 ; hash_data_type_next [3:0] $end
$var reg 4 < hash_data_type_reg [3:0] $end
$var reg 1 = hash_data_udp_next $end
$var reg 1 > hash_data_udp_reg $end
$var reg 1 ? hash_data_valid_next $end
$var reg 1 @ hash_data_valid_reg $end
$var reg 32 A hash_part_ipv4_ip_reg [31:0] $end
$var reg 32 B hash_part_ipv4_port_reg [31:0] $end
$var reg 1 C hash_part_ipv4_reg $end
$var reg 1 D hash_part_tcp_reg $end
$var reg 4 E hash_part_type_reg [3:0] $end
$var reg 1 F hash_part_udp_reg $end
$var reg 1 G hash_part_valid_reg $end
$var reg 32 H hash_reg [31:0] $end
$var reg 4 I hash_type_reg [3:0] $end
$var reg 1 J hash_valid_reg $end
$var reg 4 K ihl_next [3:0] $end
$var reg 4 L ihl_reg [3:0] $end
$var reg 3 M ptr_next [2:0] $end
$var reg 3 N ptr_reg [2:0] $end
$scope function hash_toep $end
$var reg 288 O data [287:0] $end
$var reg 320 P key [319:0] $end
$var reg 6 Q len [5:0] $end
$var integer 32 R i [31:0] $end
$var integer 32 S j [31:0] $end
$upscope $end
$upscope $end
$scope module rx_hash $end
$scope function hash_toep $end
$upscope $end
$upscope $end
$enddefinitions $end
$comment Show the parameter values. $end
$dumpall
b11 0
b1000 /
b1000000 .
b101 -
$end
#0
$dumpvars
b1000 S
b100 R
b100 Q
bz0000000000000000000000000000000000000000000000000000000000000000 P
b0 O
b0 N
b0 M
b0 L
b0 K
0J
b0 I
b0 H
0G
0F
b0 E
0D
0C
b0 B
b0 A
0@
0?
0>
0=
b0 <
b0 ;
0:
09
b0 8
b0 7
06
05
b0 4
b0 3
12
11
b0 ,
b0 +
z*
z)
bz (
bz '
z&
0%
b0 $
b0 #
bz "
z!
$end
