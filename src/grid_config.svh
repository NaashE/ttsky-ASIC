// =============================================================================
// grid_config.svh  –  Single place to switch between 4³, 8³ and 32³ voxel grids.
//
// Edit ONE line below, then re-synthesise / re-simulate.
// Also update VOXEL_GRID_SIZE in config.py to keep the Python side in sync.
//
//   GRID_4x4x4    → Ultra-tiny mode   (~3.4 K FFs)
//   GRID_8x8x8    → TinyTapeout mode  (~5.8 K FFs)
//   GRID_32x32x32 → Full-quality mode (~167 K FFs)
// =============================================================================
`ifndef GRID_CONFIG_SVH
`define GRID_CONFIG_SVH

// ── Pick ONE ─────────────────────────────────────────────────────────────────
`define GRID_32x32x32    // Full quality: ~167 K FFs  ◄ active
//`define GRID_8x8x8       // TinyTapeout: ~5.8 K FFs
//`define GRID_4x4x4       // Ultra-tiny: ~3.4 K FFs
// ─────────────────────────────────────────────────────────────────────────────

`ifdef GRID_4x4x4
  `define GRID_N             4
  `define GRID_ADDR_BITS     6          // COORD_BITS × 3  =  2×3
  `define GRID_COORD_BITS    2          // ceil(log2(4))
  `define GRID_COORD_WIDTH   8          // hit_voxel output width
  `define GRID_MAX_VAL       3          // GRID_N − 1
  `define GRID_MAX_VAL_8B    8'd3       // 8-bit literal for threshold compare
  `define GRID_MAX_VAL_LIT   2'd3       // COORD_BITS-wide literal
  `define GRID_MAX_STEPS     10'd32     // GRID_N × 8
  `define GRID_BMAX_Q88      16'sh0400  // GRID_N × 256  in Q8.8
  `define GRID_FB_DEPTH      15         // frame-buffer entries − 1  (= 4×4)
  `define GRID_FB_AWIDTH     4          // address width = ceil(log2(16))
  `define GRID_FB_ADDR_EXPR  ((rpy * cfg_w_r) + rpx)
  `define GRID_CFG_WH        8'd4       // default render width / height
  `define GRID_CAM_PX        16'sh0780  //  7.5 in Q8.8
  `define GRID_CAM_PY        16'sh0640  //  6.25 in Q8.8
  `define GRID_CAM_PZ        16'sh0780  //  7.5 in Q8.8
  `define GRID_LX            16'sh0140  //  1.25 in Q8.8
  `define GRID_LY            16'sh0500  //  5.0 in Q8.8
  `define GRID_LZ            16'sh03C0  //  3.75 in Q8.8
  `define GRID_RDPX_ASSIGN   pbuf[0]
  `define GRID_VWR_BADDR     {pbuf[0][2:0], 3'd0}
  // Area-optimised parameters for 4×4×4
  `define GRID_MAX_PL        28         // max protocol payload bytes (SET_CAMERA=24B + margin)
  `define GRID_STEP_CNT_W    10         // must be >= MAX_STEPS_BITS (10); FSM counter width
`elsif GRID_8x8x8
  `define GRID_N             8
  `define GRID_ADDR_BITS     9          // COORD_BITS × 3  =  3×3
  `define GRID_COORD_BITS    3          // ceil(log2(8))
  `define GRID_COORD_WIDTH   8          // hit_voxel output width
  `define GRID_MAX_VAL       7          // GRID_N − 1
  `define GRID_MAX_VAL_8B    8'd7       // 8-bit literal for threshold compare
  `define GRID_MAX_VAL_LIT   3'd7       // COORD_BITS-wide literal
  `define GRID_MAX_STEPS     10'd64     // GRID_N × 8
  `define GRID_BMAX_Q88      16'sh0800  // GRID_N × 256  in Q8.8
  `define GRID_FB_DEPTH      255        // frame-buffer entries − 1  (= 16×16)
  `define GRID_FB_AWIDTH     8          // address width = ceil(log2(256))
  `define GRID_FB_ADDR_EXPR  ((rpy * cfg_w_r) + rpx)
  `define GRID_CFG_WH        8'd8       // default render width / height
  `define GRID_CAM_PX        16'sh0F00  // 15.0 in Q8.8
  `define GRID_CAM_PY        16'sh0C80  // 12.5 in Q8.8
  `define GRID_CAM_PZ        16'sh0F00  // 15.0 in Q8.8
  `define GRID_LX            16'sh0280  //  2.5 in Q8.8
  `define GRID_LY            16'sh0A00  // 10.0 in Q8.8
  `define GRID_LZ            16'sh0780  //  7.5 in Q8.8
  `define GRID_RDPX_ASSIGN   pbuf[0]
  `define GRID_VWR_BADDR     {pbuf[0][5:0], 3'd0}
  // Area-optimised parameters for 8×8×8
  `define GRID_MAX_PL        72         // max protocol payload bytes (3 hdr + 64 voxel + margin)
  `define GRID_STEP_CNT_W    10         // ceil(log2(64+1)) + margin steps counter width
`else  // GRID_32x32x32
  `define GRID_N             32
  `define GRID_ADDR_BITS     15         // COORD_BITS × 3  =  5×3
  `define GRID_COORD_BITS    5          // ceil(log2(32))
  `define GRID_COORD_WIDTH   16         // hit_voxel output width
  `define GRID_MAX_VAL       31         // GRID_N − 1
  `define GRID_MAX_VAL_8B    8'd31      // 8-bit literal for threshold compare
  `define GRID_MAX_VAL_LIT   5'd31      // COORD_BITS-wide literal
  `define GRID_MAX_STEPS     10'd512    // GRID_N × 16
  `define GRID_BMAX_Q88      16'sh2000  // GRID_N × 256  in Q8.8
  `define GRID_FB_DEPTH      16383      // frame-buffer entries − 1  (= 128×128)
  `define GRID_FB_AWIDTH     14         // address width = ceil(log2(16384))
  `define GRID_FB_ADDR_EXPR  ({7'b0, rpy} * {7'b0, cfg_w_r} + {7'b0, rpx})
  `define GRID_CFG_WH        8'd32      // default render width / height
  `define GRID_CAM_PX        16'sh3C00  // 60.0 in Q8.8
  `define GRID_CAM_PY        16'sh3200  // 50.0 in Q8.8
  `define GRID_CAM_PZ        16'sh3C00  // 60.0 in Q8.8
  `define GRID_LX            16'sh0A00  // 10.0 in Q8.8
  `define GRID_LY            16'sh2800  // 40.0 in Q8.8
  `define GRID_LZ            16'sh1E00  // 30.0 in Q8.8
  `define GRID_RDPX_ASSIGN   {pbuf[1][5:0], pbuf[0]}
  `define GRID_VWR_BADDR     {pbuf[1][4:0], pbuf[0], 3'd0}
  // Area-optimised parameters for 32×32×32
  `define GRID_MAX_PL        72         // max protocol payload bytes (host chunks large writes)
  `define GRID_STEP_CNT_W    10         // ceil(log2(512+1)) steps counter width
`endif

`endif // GRID_CONFIG_SVH
