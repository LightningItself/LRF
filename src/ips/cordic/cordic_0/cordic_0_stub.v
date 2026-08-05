// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
// Date        : Wed Aug  5 18:57:37 2026
// Host        : vlsi-srv.iitbbs.ac.in running 64-bit Red Hat Enterprise Linux 9.6 (Plow)
// Command     : write_verilog -force -mode synth_stub
//               /home/23EC01052/Desktop/ip_gen/cordic/cordic.gen/sources_1/ip/cordic_0/cordic_0_stub.v
// Design      : cordic_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xczu9eg-ffvb1156-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "cordic_0,cordic_v6_0_23,{}" *) (* core_generation_info = "cordic_0,cordic_v6_0_23,{x_ipProduct=Vivado 2024.2,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=cordic,x_ipVersion=6.0,x_ipCoreRevision=23,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_ARCHITECTURE=2,C_CORDIC_FUNCTION=6,C_COARSE_ROTATE=0,C_DATA_FORMAT=2,C_XDEVICEFAMILY=zynquplus,C_HAS_ACLKEN=1,C_HAS_ACLK=1,C_HAS_S_AXIS_CARTESIAN=1,C_HAS_S_AXIS_PHASE=0,C_HAS_ARESETN=1,C_INPUT_WIDTH=24,C_ITERATIONS=0,C_OUTPUT_WIDTH=13,C_PHASE_FORMAT=0,C_PIPELINE_MODE=-2,C_PRECISION=0,C_ROUND_MODE=0,C_SCALE_COMP=0,C_THROTTLE_SCHEME=3,C_TLAST_RESOLUTION=1,C_HAS_S_AXIS_PHASE_TUSER=0,C_HAS_S_AXIS_PHASE_TLAST=0,C_S_AXIS_PHASE_TDATA_WIDTH=24,C_S_AXIS_PHASE_TUSER_WIDTH=1,C_HAS_S_AXIS_CARTESIAN_TUSER=0,C_HAS_S_AXIS_CARTESIAN_TLAST=1,C_S_AXIS_CARTESIAN_TDATA_WIDTH=24,C_S_AXIS_CARTESIAN_TUSER_WIDTH=1,C_M_AXIS_DOUT_TDATA_WIDTH=16,C_M_AXIS_DOUT_TUSER_WIDTH=1}" *) (* downgradeipidentifiedwarnings = "yes" *) 
(* x_core_info = "cordic_v6_0_23,Vivado 2024.2" *) 
module cordic_0(aclk, aclken, aresetn, s_axis_cartesian_tvalid, 
  s_axis_cartesian_tlast, s_axis_cartesian_tdata, m_axis_dout_tvalid, m_axis_dout_tlast, 
  m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclken,aresetn,s_axis_cartesian_tvalid,s_axis_cartesian_tlast,s_axis_cartesian_tdata[23:0],m_axis_dout_tvalid,m_axis_dout_tlast,m_axis_dout_tdata[15:0]" */
/* synthesis syn_force_seq_prim="aclk" */;
  (* x_interface_info = "xilinx.com:signal:clock:1.0 aclk_intf CLK" *) (* x_interface_mode = "slave aclk_intf" *) (* x_interface_parameter = "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF M_AXIS_DOUT:S_AXIS_PHASE:S_AXIS_CARTESIAN, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 1000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0" *) input aclk /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:signal:clockenable:1.0 aclken_intf CE" *) (* x_interface_mode = "slave aclken_intf" *) (* x_interface_parameter = "XIL_INTERFACENAME aclken_intf, POLARITY ACTIVE_HIGH" *) input aclken;
  (* x_interface_info = "xilinx.com:signal:reset:1.0 aresetn_intf RST" *) (* x_interface_mode = "slave aresetn_intf" *) (* x_interface_parameter = "XIL_INTERFACENAME aresetn_intf, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input aresetn;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TVALID" *) (* x_interface_mode = "slave S_AXIS_CARTESIAN" *) (* x_interface_parameter = "XIL_INTERFACENAME S_AXIS_CARTESIAN, TDATA_NUM_BYTES 3, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0" *) input s_axis_cartesian_tvalid;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TLAST" *) input s_axis_cartesian_tlast;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TDATA" *) input [23:0]s_axis_cartesian_tdata;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TVALID" *) (* x_interface_mode = "master M_AXIS_DOUT" *) (* x_interface_parameter = "XIL_INTERFACENAME M_AXIS_DOUT, TDATA_NUM_BYTES 2, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0" *) output m_axis_dout_tvalid;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TLAST" *) output m_axis_dout_tlast;
  (* x_interface_info = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TDATA" *) output [15:0]m_axis_dout_tdata;
endmodule
