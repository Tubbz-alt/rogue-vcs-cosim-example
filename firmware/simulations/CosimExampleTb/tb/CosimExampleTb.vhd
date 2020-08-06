-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue/VCS Co-simulation Example
-------------------------------------------------------------------------------
-- This file is part of 'rogue-vcs-cosim-example'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'rogue-vcs-cosim-example', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity CosimExampleTb is end CosimExampleTb;

architecture testbed of CosimExampleTb is

   -----------------------------
   -- Define the clock frequency
   -----------------------------
   constant CLK_PERIOD_C : time := 10 ns;  -- 100 MHz
   constant TPD_C        : time := CLK_PERIOD_C/4;

   -------------------------------
   -- Force githash for simulation
   -------------------------------
   constant GET_BUILD_INFO_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);
   constant MOD_BUILD_INFO_C : BuildInfoRetType := (
      buildString => GET_BUILD_INFO_C.buildString,
      fwVersion   => GET_BUILD_INFO_C.fwVersion,
      gitHash     => x"1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA");  -- Force githash
   constant SIM_BUILD_INFO_C : slv(2239 downto 0) := toSlv(MOD_BUILD_INFO_C);

   ------------------------------
   -- AXI-Lite XBAR Configuration
   ------------------------------
   constant VERSION_INDEX_C    : natural  := 0;
   constant PRBS_TX_INDEX_C    : natural  := 1;
   constant PRBS_RX_INDEX_C    : natural  := 2;
   constant NUM_AXIL_MASTERS_C : positive := 3;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", 16, 12);

   ---------------------------------------
   -- 32-bit (4 byte) AXI stream interface
   ---------------------------------------
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   ----------
   -- Signals
   ----------
   signal clk : sl := '0';
   signal rst : sl := '1';

   signal mAxilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal mAxilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal dmaIbMasters : AxiStreamMasterArray(2 downto 0);
   signal dmaIbSlaves  : AxiStreamSlaveArray(2 downto 0);
   signal dmaObMasters : AxiStreamMasterArray(2 downto 0);
   signal dmaObSlaves  : AxiStreamSlaveArray(2 downto 0);

begin

   ------------------
   -- Clock and Reset
   ------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         rst  => rst);

   -------------------------
   -- TCP to AXI-Lite Bridge
   -------------------------
   U_TcpToAxiLite : entity surf.RogueTcpMemoryWrap
      generic map (
         TPD_G      => TPD_C,
         PORT_NUM_G => 9000)            -- TCP ports [9000:9001]
      port map (
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => mAxilReadMasters(0),
         axilReadSlave   => mAxilReadSlaves(0),
         axilWriteMaster => mAxilWriteMasters(0),
         axilWriteSlave  => mAxilWriteSlaves(0));

   ---------------------------
   -- TCP to AXI Stream Bridge
   ---------------------------
   GEN_DMA : for i in 2 downto 0 generate
      U_TcpToAxiStream : entity surf.RogueTcpStreamWrap
         generic map (
            TPD_G         => TPD_C,
            PORT_NUM_G    => 10000+2*i,  -- TCP ports [10000+2*i+0:10000+2*i+1]
            AXIS_CONFIG_G => AXIS_CONFIG_C)
         port map (
            axisClk     => clk,
            axisRst     => rst,
            sAxisMaster => dmaIbMasters(i),
            sAxisSlave  => dmaIbSlaves(i),
            mAxisMaster => dmaObMasters(i),
            mAxisSlave  => dmaObSlaves(i));
   end generate GEN_DMA;

   -------------------
   -- DMA[0]: Loopback
   -------------------
   dmaIbMasters(0) <= dmaObMasters(0);
   dmaObSlaves(0)  <= dmaIbSlaves(0);

   -------------------
   -- DMA[1]: SRPv3
   -------------------
   U_SRPv3 : entity surf.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_C,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain)
         sAxisClk         => clk,
         sAxisRst         => rst,
         sAxisMaster      => dmaObMasters(1),
         sAxisSlave       => dmaObSlaves(1),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => clk,
         mAxisRst         => rst,
         mAxisMaster      => dmaIbMasters(1),
         mAxisSlave       => dmaIbSlaves(1),
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => clk,
         axilRst          => rst,
         mAxilReadMaster  => mAxilReadMasters(1),
         mAxilReadSlave   => mAxilReadSlaves(1),
         mAxilWriteMaster => mAxilWriteMasters(1),
         mAxilWriteSlave  => mAxilWriteSlaves(1));

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------         
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_C,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk           => clk,
         axiClkRst        => rst,
         sAxiWriteMasters => mAxilWriteMasters,
         sAxiWriteSlaves  => mAxilWriteSlaves,
         sAxiReadMasters  => mAxilReadMasters,
         sAxiReadSlaves   => mAxilReadSlaves,
         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves);

   --------------------
   -- AxiVersion Module
   --------------------
   U_Version : entity surf.AxiVersion
      generic map (
         TPD_G        => TPD_C,
         BUILD_INFO_G => SIM_BUILD_INFO_C)
      port map (
         -- AXI-Lite Interface
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C));

   ------------------
   -- DMA[2]: PRBS TX
   ------------------
   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_C,
         AXI_EN_G                   => '1',
         MASTER_AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         mAxisClk        => clk,
         mAxisRst        => rst,
         mAxisMaster     => dmaIbMasters(2),
         mAxisSlave      => dmaIbSlaves(2),
         locClk          => clk,
         locRst          => rst,
         trig            => '0',
         packetLength    => X"000000ff",
         tDest           => X"00",
         tId             => X"00",
         axilReadMaster  => axilReadMasters(PRBS_TX_INDEX_C),
         axilReadSlave   => axilReadSlaves(PRBS_TX_INDEX_C),
         axilWriteMaster => axilWriteMasters(PRBS_TX_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(PRBS_TX_INDEX_C));

   ------------------
   -- DMA[2]: PRBS RX
   ------------------
   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_C,
         SLAVE_AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => dmaObMasters(2),
         sAxisSlave     => dmaObSlaves(2),
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => axilReadMasters(PRBS_RX_INDEX_C),
         axiReadSlave   => axilReadSlaves(PRBS_RX_INDEX_C),
         axiWriteMaster => axilWriteMasters(PRBS_RX_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(PRBS_RX_INDEX_C));

end testbed;
