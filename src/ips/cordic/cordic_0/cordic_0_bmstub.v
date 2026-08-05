// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module cordic_0 (
  aclk,
  aclken,
  aresetn,
  s_axis_cartesian_tvalid,
  s_axis_cartesian_tlast,
  s_axis_cartesian_tdata,
  m_axis_dout_tvalid,
  m_axis_dout_tlast,
  m_axis_dout_tdata
);

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk_intf CLK" *)
  (* X_INTERFACE_MODE = "slave aclk_intf" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF M_AXIS_DOUT:S_AXIS_PHASE:S_AXIS_CARTESIAN, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 1000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN , ASSOCIATED_PORT , INSERT_VIP 0" *)
  input aclk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clockenable:1.0 aclken_intf CE" *)
  (* X_INTERFACE_MODE = "slave aclken_intf" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclken_intf, POLARITY ACTIVE_HIGH" *)
  input aclken;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn_intf RST" *)
  (* X_INTERFACE_MODE = "slave aresetn_intf" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn_intf, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
  input aresetn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TVALID" *)
  (* X_INTERFACE_MODE = "slave S_AXIS_CARTESIAN" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXIS_CARTESIAN, TDATA_NUM_BYTES 3, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN , LAYERED_METADATA undef, INSERT_VIP 0" *)
  input s_axis_cartesian_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TLAST" *)
  input s_axis_cartesian_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TDATA" *)
  input [23:0]s_axis_cartesian_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TVALID" *)
  (* X_INTERFACE_MODE = "master M_AXIS_DOUT" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXIS_DOUT, TDATA_NUM_BYTES 2, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN , LAYERED_METADATA undef, INSERT_VIP 0" *)
  output m_axis_dout_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TLAST" *)
  output m_axis_dout_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TDATA" *)
  output [15:0]m_axis_dout_tdata;

  // stub module has no contents

endmodule
