/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC Interface TX path
 */
module mqnic_interface_tx #
(
    // Number of ports
    parameter PORTS = 1,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 16,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Descriptor request tag field width
    parameter DESC_REQ_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Transmit queue index width
    parameter TX_QUEUE_INDEX_WIDTH = 8,
    // Max queue index width
    parameter QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH,
    // Transmit completion queue index width
    parameter TX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Max completion queue index width
    parameter CPL_QUEUE_INDEX_WIDTH = TX_CPL_QUEUE_INDEX_WIDTH,
    // Transmit descriptor table size (number of in-flight operations)
    parameter TX_DESC_TABLE_SIZE = 16,
    // Width of descriptor table field for tracking outstanding DMA operations
    parameter DESC_TABLE_DMA_OP_COUNT_WIDTH = 4,
    // Max number of in-flight descriptor requests (transmit)
    parameter TX_MAX_DESC_REQ = 16,
    // Transmit descriptor FIFO size
    parameter TX_DESC_FIFO_SIZE = TX_MAX_DESC_REQ*8,
    // Scheduler operation table size
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 32,
    // Scheduler pipeline setting
    parameter TX_SCHEDULER_PIPELINE = 3,
    // Scheduler TDMA index width
    parameter TDMA_INDEX_WIDTH = 8,
    // Interrupt number width
    parameter INT_WIDTH = 8,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Queue log size field width
    parameter LOG_QUEUE_SIZE_WIDTH = 4,
    // Log desc block size field width
    parameter LOG_BLOCK_SIZE_WIDTH = 2,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // PTP tag width
    parameter PTP_TAG_WIDTH = 16,
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1,
    // DMA RAM segment count
    parameter SEG_COUNT = 2,
    // DMA RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // DMA RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // DMA RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // DMA RAM pipeline stages
    parameter RAM_PIPELINE = 2,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tid signal width
    parameter AXIS_TX_ID_WIDTH = TX_QUEUE_INDEX_WIDTH,
    // AXI stream tdest signal width
    parameter AXIS_TX_DEST_WIDTH = $clog2(PORTS)+4,
    // AXI stream tuser signal width
    parameter AXIS_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048,
    // DMA TX RAM size
    parameter TX_RAM_SIZE = 8*MAX_TX_SIZE,
    // Descriptor size (in bytes)
    parameter DESC_SIZE = 16,
    // Descriptor size (in bytes)
    parameter CPL_SIZE = 32,
    // Width of AXI stream descriptor interfaces in bits
    parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8,
    // AXI stream descriptor tkeep signal width (words per cycle)
    parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * Transmit request input (queue index)
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]         s_axis_tx_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_tx_req_tag,
    input  wire [AXIS_TX_DEST_WIDTH-1:0]        s_axis_tx_req_dest,
    input  wire                                 s_axis_tx_req_valid,
    output wire                                 s_axis_tx_req_ready,

    /*
     * Transmit request status output
     */
    output wire [DMA_CLIENT_LEN_WIDTH-1:0]      m_axis_tx_req_status_len,
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_tx_req_status_tag,
    output wire                                 m_axis_tx_req_status_valid,

    /*
     * Descriptor request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]         m_axis_desc_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]        m_axis_desc_req_tag,
    output wire                                 m_axis_desc_req_valid,
    input  wire                                 m_axis_desc_req_ready,

    /*
     * Descriptor request status input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]         s_axis_desc_req_status_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_desc_req_status_ptr,
    input  wire [CPL_QUEUE_INDEX_WIDTH-1:0]     s_axis_desc_req_status_cpl,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_desc_req_status_tag,
    input  wire                                 s_axis_desc_req_status_empty,
    input  wire                                 s_axis_desc_req_status_error,
    input  wire                                 s_axis_desc_req_status_valid,

    /*
     * Descriptor data input
     */
    input  wire [AXIS_DESC_DATA_WIDTH-1:0]      s_axis_desc_tdata,
    input  wire [AXIS_DESC_KEEP_WIDTH-1:0]      s_axis_desc_tkeep,
    input  wire                                 s_axis_desc_tvalid,
    output wire                                 s_axis_desc_tready,
    input  wire                                 s_axis_desc_tlast,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_desc_tid,
    input  wire                                 s_axis_desc_tuser,

    /*
     * Completion request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]         m_axis_cpl_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]        m_axis_cpl_req_tag,
    output wire [CPL_SIZE*8-1:0]                m_axis_cpl_req_data,
    output wire                                 m_axis_cpl_req_valid,
    input  wire                                 m_axis_cpl_req_ready,

    /*
     * Completion request status input
     */
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_cpl_req_status_tag,
    input  wire                                 s_axis_cpl_req_status_full,
    input  wire                                 s_axis_cpl_req_status_error,
    input  wire                                 s_axis_cpl_req_status_valid,

    /*
     * DMA read descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]            m_axis_dma_read_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]            m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]             m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]             m_axis_dma_read_desc_tag,
    output wire                                 m_axis_dma_read_desc_valid,
    input  wire                                 m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]             s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                           s_axis_dma_read_desc_status_error,
    input  wire                                 s_axis_dma_read_desc_status_valid,

    /*
     * RAM interface (data)
     */
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                 dma_ram_wr_done,

    /*
     * Transmit data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]           tx_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]           tx_axis_tkeep,
    output wire                                 tx_axis_tvalid,
    input  wire                                 tx_axis_tready,
    output wire                                 tx_axis_tlast,
    output wire [AXIS_TX_ID_WIDTH-1:0]          tx_axis_tid,
    output wire [AXIS_TX_DEST_WIDTH-1:0]        tx_axis_tdest,
    output wire [AXIS_TX_USER_WIDTH-1:0]        tx_axis_tuser,

    /*
     * Transmit timestamp input
     */
    input  wire [PTP_TS_WIDTH-1:0]              s_axis_tx_ptp_ts,
    input  wire [PTP_TAG_WIDTH-1:0]             s_axis_tx_ptp_ts_tag,
    input  wire                                 s_axis_tx_ptp_ts_valid,
    output wire                                 s_axis_tx_ptp_ts_ready,

    /*
     * PTP clock
     */
    input  wire [95:0]                          ptp_ts_96,
    input  wire                                 ptp_ts_step,

    /*
     * Configuration
     */
    input  wire [DMA_CLIENT_LEN_WIDTH-1:0]      mtu
);

parameter DMA_CLIENT_TAG_WIDTH = $clog2(TX_DESC_TABLE_SIZE);
parameter DMA_CLIENT_LEN_WIDTH = DMA_LEN_WIDTH;

wire [AXIS_DESC_DATA_WIDTH-1:0]  tx_fifo_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]  tx_fifo_desc_tkeep;
wire                             tx_fifo_desc_tvalid;
wire                             tx_fifo_desc_tready;
wire                             tx_fifo_desc_tlast;
wire [DESC_REQ_TAG_WIDTH-1:0]    tx_fifo_desc_tid;
wire                             tx_fifo_desc_tuser;

axis_fifo #(
    .DEPTH(TX_DESC_FIFO_SIZE*DESC_SIZE),
    .DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(1),
    .ID_WIDTH(DESC_REQ_TAG_WIDTH),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .PIPELINE_OUTPUT(3),
    .FRAME_FIFO(0)
)
tx_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_axis_desc_tdata),
    .s_axis_tkeep(s_axis_desc_tkeep),
    .s_axis_tvalid(s_axis_desc_tvalid),
    .s_axis_tready(s_axis_desc_tready),
    .s_axis_tlast(s_axis_desc_tlast),
    .s_axis_tid(s_axis_desc_tid),
    .s_axis_tdest(0),
    .s_axis_tuser(s_axis_desc_tuser),

    // AXI output
    .m_axis_tdata(tx_fifo_desc_tdata),
    .m_axis_tkeep(tx_fifo_desc_tkeep),
    .m_axis_tvalid(tx_fifo_desc_tvalid),
    .m_axis_tready(tx_fifo_desc_tready),
    .m_axis_tlast(tx_fifo_desc_tlast),
    .m_axis_tid(tx_fifo_desc_tid),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_desc_tuser),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

wire        tx_csum_cmd_csum_enable;
wire [7:0]  tx_csum_cmd_csum_start;
wire [7:0]  tx_csum_cmd_csum_offset;
wire        tx_csum_cmd_valid;
wire        tx_csum_cmd_ready;

wire [RAM_ADDR_WIDTH-1:0]        dma_tx_desc_addr;
wire [DMA_CLIENT_LEN_WIDTH-1:0]  dma_tx_desc_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0]  dma_tx_desc_tag;
wire [AXIS_TX_ID_WIDTH-1:0]      dma_tx_desc_id;
wire [AXIS_TX_DEST_WIDTH-1:0]    dma_tx_desc_dest;
wire [AXIS_TX_USER_WIDTH-1:0]    dma_tx_desc_user;
wire                             dma_tx_desc_valid;
wire                             dma_tx_desc_ready;

wire [DMA_CLIENT_TAG_WIDTH-1:0]  dma_tx_desc_status_tag;
wire [3:0]                       dma_tx_desc_status_error;
wire                             dma_tx_desc_status_valid;

tx_engine #(
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_CLIENT_LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .DMA_CLIENT_TAG_WIDTH(DMA_CLIENT_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(DESC_TABLE_DMA_OP_COUNT_WIDTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .TX_BUFFER_OFFSET(0),
    .TX_BUFFER_SIZE(TX_RAM_SIZE),
    .TX_BUFFER_STEP_SIZE(SEG_COUNT*SEG_BE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .MAX_DESC_REQ(TX_MAX_DESC_REQ),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .AXIS_TX_ID_WIDTH(AXIS_TX_ID_WIDTH),
    .AXIS_TX_DEST_WIDTH(AXIS_TX_DEST_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_TX_USER_WIDTH)
)
tx_engine_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Transmit request input (queue index)
     */
    .s_axis_tx_req_queue(s_axis_tx_req_queue),
    .s_axis_tx_req_tag(s_axis_tx_req_tag),
    .s_axis_tx_req_dest(s_axis_tx_req_dest),
    .s_axis_tx_req_valid(s_axis_tx_req_valid),
    .s_axis_tx_req_ready(s_axis_tx_req_ready),

    /*
     * Transmit request status output
     */
    .m_axis_tx_req_status_len(m_axis_tx_req_status_len),
    .m_axis_tx_req_status_tag(m_axis_tx_req_status_tag),
    .m_axis_tx_req_status_valid(m_axis_tx_req_status_valid),

    /*
     * Descriptor request output
     */
    .m_axis_desc_req_queue(m_axis_desc_req_queue),
    .m_axis_desc_req_tag(m_axis_desc_req_tag),
    .m_axis_desc_req_valid(m_axis_desc_req_valid),
    .m_axis_desc_req_ready(m_axis_desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_desc_req_status_queue(s_axis_desc_req_status_queue),
    .s_axis_desc_req_status_ptr(s_axis_desc_req_status_ptr),
    .s_axis_desc_req_status_cpl(s_axis_desc_req_status_cpl),
    .s_axis_desc_req_status_tag(s_axis_desc_req_status_tag),
    .s_axis_desc_req_status_empty(s_axis_desc_req_status_empty),
    .s_axis_desc_req_status_error(s_axis_desc_req_status_error),
    .s_axis_desc_req_status_valid(s_axis_desc_req_status_valid),

    /*
     * Descriptor data input
     */
    .s_axis_desc_tdata(tx_fifo_desc_tdata),
    .s_axis_desc_tkeep(tx_fifo_desc_tkeep),
    .s_axis_desc_tvalid(tx_fifo_desc_tvalid),
    .s_axis_desc_tready(tx_fifo_desc_tready),
    .s_axis_desc_tlast(tx_fifo_desc_tlast),
    .s_axis_desc_tid(tx_fifo_desc_tid),
    .s_axis_desc_tuser(tx_fifo_desc_tuser),

    /*
     * Completion request output
     */
    .m_axis_cpl_req_queue(m_axis_cpl_req_queue),
    .m_axis_cpl_req_tag(m_axis_cpl_req_tag),
    .m_axis_cpl_req_data(m_axis_cpl_req_data),
    .m_axis_cpl_req_valid(m_axis_cpl_req_valid),
    .m_axis_cpl_req_ready(m_axis_cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_cpl_req_status_tag(s_axis_cpl_req_status_tag),
    .s_axis_cpl_req_status_full(s_axis_cpl_req_status_full),
    .s_axis_cpl_req_status_error(s_axis_cpl_req_status_error),
    .s_axis_cpl_req_status_valid(s_axis_cpl_req_status_valid),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(m_axis_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_addr(m_axis_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(m_axis_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(m_axis_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(m_axis_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(m_axis_dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(s_axis_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(s_axis_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(s_axis_dma_read_desc_status_valid),

    /*
     * Transmit descriptor output
     */
    .m_axis_tx_desc_addr(dma_tx_desc_addr),
    .m_axis_tx_desc_len(dma_tx_desc_len),
    .m_axis_tx_desc_tag(dma_tx_desc_tag),
    .m_axis_tx_desc_id(dma_tx_desc_id),
    .m_axis_tx_desc_dest(dma_tx_desc_dest),
    .m_axis_tx_desc_user(dma_tx_desc_user),
    .m_axis_tx_desc_valid(dma_tx_desc_valid),
    .m_axis_tx_desc_ready(dma_tx_desc_ready),

    /*
     * Transmit descriptor status input
     */
    .s_axis_tx_desc_status_tag(dma_tx_desc_status_tag),
    .s_axis_tx_desc_status_error(dma_tx_desc_status_error),
    .s_axis_tx_desc_status_valid(dma_tx_desc_status_valid),

    /*
     * Transmit checksum command output
     */
    .m_axis_tx_csum_cmd_csum_enable(tx_csum_cmd_csum_enable),
    .m_axis_tx_csum_cmd_csum_start(tx_csum_cmd_csum_start),
    .m_axis_tx_csum_cmd_csum_offset(tx_csum_cmd_csum_offset),
    .m_axis_tx_csum_cmd_valid(tx_csum_cmd_valid),
    .m_axis_tx_csum_cmd_ready(tx_csum_cmd_ready),

    /*
     * Transmit timestamp input
     */
    .s_axis_tx_ptp_ts(s_axis_tx_ptp_ts),
    .s_axis_tx_ptp_ts_tag(s_axis_tx_ptp_ts_tag),
    .s_axis_tx_ptp_ts_valid(s_axis_tx_ptp_ts_valid),
    .s_axis_tx_ptp_ts_ready(s_axis_tx_ptp_ts_ready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready_int;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready_int;

dma_psdpram #(
    .SIZE(TX_RAM_SIZE),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .PIPELINE(RAM_PIPELINE)
)
dma_psdpram_tx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(dma_ram_wr_cmd_be),
    .wr_cmd_addr(dma_ram_wr_cmd_addr),
    .wr_cmd_data(dma_ram_wr_cmd_data),
    .wr_cmd_valid(dma_ram_wr_cmd_valid),
    .wr_cmd_ready(dma_ram_wr_cmd_ready),
    .wr_done(dma_ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .rd_resp_data(dma_ram_rd_resp_data_int),
    .rd_resp_valid(dma_ram_rd_resp_valid_int),
    .rd_resp_ready(dma_ram_rd_resp_ready_int)
);

wire [AXIS_DATA_WIDTH-1:0]     tx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0]     tx_axis_tkeep_int;
wire                           tx_axis_tvalid_int;
wire                           tx_axis_tready_int;
wire                           tx_axis_tlast_int;
wire [AXIS_TX_ID_WIDTH-1:0]    tx_axis_tid_int;
wire [AXIS_TX_DEST_WIDTH-1:0]  tx_axis_tdest_int;
wire [AXIS_TX_USER_WIDTH-1:0]  tx_axis_tuser_int;

dma_client_axis_source #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(AXIS_TX_ID_WIDTH),
    .AXIS_DEST_ENABLE(1),
    .AXIS_DEST_WIDTH(AXIS_TX_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_TX_USER_WIDTH),
    .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .TAG_WIDTH(DMA_CLIENT_TAG_WIDTH)
)
dma_client_axis_source_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA read descriptor input
     */
    .s_axis_read_desc_ram_addr(dma_tx_desc_addr),
    .s_axis_read_desc_len(dma_tx_desc_len),
    .s_axis_read_desc_tag(dma_tx_desc_tag),
    .s_axis_read_desc_id(dma_tx_desc_id),
    .s_axis_read_desc_dest(dma_tx_desc_dest),
    .s_axis_read_desc_user(dma_tx_desc_user),
    .s_axis_read_desc_valid(dma_tx_desc_valid),
    .s_axis_read_desc_ready(dma_tx_desc_ready),

    /*
     * DMA read descriptor status output
     */
    .m_axis_read_desc_status_tag(dma_tx_desc_status_tag),
    .m_axis_read_desc_status_error(dma_tx_desc_status_error),
    .m_axis_read_desc_status_valid(dma_tx_desc_status_valid),

    /*
     * AXI stream read data output
     */
    .m_axis_read_data_tdata(tx_axis_tdata_int),
    .m_axis_read_data_tkeep(tx_axis_tkeep_int),
    .m_axis_read_data_tvalid(tx_axis_tvalid_int),
    .m_axis_read_data_tready(tx_axis_tready_int),
    .m_axis_read_data_tlast(tx_axis_tlast_int),
    .m_axis_read_data_tid(tx_axis_tid_int),
    .m_axis_read_data_tdest(tx_axis_tdest_int),
    .m_axis_read_data_tuser(tx_axis_tuser_int),

    /*
     * RAM interface
     */
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .ram_rd_resp_data(dma_ram_rd_resp_data_int),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid_int),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready_int),

    /*
     * Configuration
     */
    .enable(1'b1)
);

mqnic_egress #(
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_ID_WIDTH(AXIS_TX_ID_WIDTH),
    .AXIS_DEST_WIDTH(AXIS_TX_DEST_WIDTH),
    .AXIS_USER_WIDTH(AXIS_TX_USER_WIDTH),
    .MAX_TX_SIZE(MAX_TX_SIZE)
)
egress_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Transmit data input
     */
    .s_axis_tdata(tx_axis_tdata_int),
    .s_axis_tkeep(tx_axis_tkeep_int),
    .s_axis_tvalid(tx_axis_tvalid_int),
    .s_axis_tready(tx_axis_tready_int),
    .s_axis_tlast(tx_axis_tlast_int),
    .s_axis_tid(tx_axis_tid_int),
    .s_axis_tdest(tx_axis_tdest_int),
    .s_axis_tuser(tx_axis_tuser_int),

    /*
     * Transmit data output
     */
    .m_axis_tdata(tx_axis_tdata),
    .m_axis_tkeep(tx_axis_tkeep),
    .m_axis_tvalid(tx_axis_tvalid),
    .m_axis_tready(tx_axis_tready),
    .m_axis_tlast(tx_axis_tlast),
    .m_axis_tid(tx_axis_tid),
    .m_axis_tdest(tx_axis_tdest),
    .m_axis_tuser(tx_axis_tuser),

    /*
     * Transmit checksum command
     */
    .tx_csum_cmd_csum_enable(tx_csum_cmd_csum_enable),
    .tx_csum_cmd_csum_start(tx_csum_cmd_csum_start),
    .tx_csum_cmd_csum_offset(tx_csum_cmd_csum_offset),
    .tx_csum_cmd_valid(tx_csum_cmd_valid),
    .tx_csum_cmd_ready(tx_csum_cmd_ready)
);

endmodule

`resetall
