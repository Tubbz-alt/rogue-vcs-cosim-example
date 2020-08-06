##############################################################################
## This file is part of 'rogue-vcs-cosim-example'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'rogue-vcs-cosim-example', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import setupLibPaths

import rogue
import rogue.interfaces.stream

import pyrogue as pr
import pyrogue.pydm
import pyrogue.utilities.prbs
import pyrogue.interfaces.simulation

import surf.axi           as axi
import surf.protocols.ssi as ssi

#################################################################

class MyDevice(pr.Device):
    def __init__(   self,
            **kwargs):
        super().__init__(**kwargs)

        self.add(axi.AxiVersion(
            offset = 0x0000,
        ))

        self.add(ssi.SsiPrbsTx(
            offset = 0x1000,
        ))

        self.add(ssi.SsiPrbsRx(
            offset = 0x2000,
        ))

#################################################################

class MyRoot(pr.Root):
    def __init__(   self,
            **kwargs):
        super().__init__(**kwargs)

        self.dmaStreams = [None for x in range(3)]
        self.memMaps    = [None for x in range(2)]

        ########################
        # TCP to AXI-Lite Bridge
        ########################
        self.memMaps[0] = rogue.interfaces.memory.TcpClient('localhost',9000)

        ##########################
        # TCP to AXI Stream Bridge
        ##########################
        for x in range(3):
            self.dmaStreams[x] = rogue.interfaces.stream.TcpClient('localhost',10000+2*x)

        ############################
        # DMA[0]: DMA Loopback at FW
        ############################

        # Create Loopback TX PRBS Module
        self.loopbackPrbsRx = pr.utilities.prbs.PrbsRx(
            name  = 'LoopbackPrbsRx',
            width = 32,
        )

        # Create Loopback TX PRBS Module
        self.loopbackPrbsTx = pr.utilities.prbs.PrbsTx(
            name  = 'LoopbackPrbsTx',
            width = 32,
        )

        # Connect to DMA
        self.dmaStreams[0]  >> self.loopbackPrbsRx
        self.loopbackPrbsTx >> self.dmaStreams[0]

        # Add Loopback device to device tree
        self.add(self.loopbackPrbsRx)
        self.add(self.loopbackPrbsTx)

        ###############
        # DMA[1]: SRPv3
        ###############

        # Create SRPv3
        self.memMaps[1] = rogue.protocols.srp.SrpV3()

        # Bidirectional connection to DMA
        self.memMaps[1] == self.dmaStreams[1]

        ##################################
        # Add Memory Map and SRPv3 devices
        ##################################

        self.add(MyDevice(
            name    = 'MemMapDevice',
            memBase = self.memMaps[0],
        ))

        self.add(MyDevice(
            name    = 'SRPv3Device',
            memBase = self.memMaps[1],
        ))

        ####################
        # DMA[2]: TX/RX PRBS
        ####################

        # Create SW TX PRBS Module
        self.swPrbsRx = pr.utilities.prbs.PrbsRx(
            name  = 'SwPrbsRx',
            width = 32,
        )

        # Create SW TX PRBS Module
        self.swPrbsTx = pr.utilities.prbs.PrbsTx(
            name  = 'SwPrbsTx',
            width = 32,
        )

        # Connect to DMA
        self.dmaStreams[0] >> self.swPrbsRx
        self.swPrbsTx      >> self.dmaStreams[0]

        # Add SW device to device tree
        self.add(self.swPrbsRx)
        self.add(self.swPrbsTx)

        #############################
        # Create some useful commands
        #############################

        @self.command()
        def EnableAllFwTx():
            fwTxDevices = root.find(typ=ssi.SsiPrbsTx)
            for tx in fwTxDevices:
                tx.TxEn.set(True)

        @self.command()
        def DisableAllFwTx():
            fwTxDevices = root.find(typ=ssi.SsiPrbsTx)
            for tx in fwTxDevices:
                tx.TxEn.set(False)

#################################################################

with MyRoot(pollEn=True, initRead=False) as root:
    pyrogue.pydm.runPyDM(root=root)

#################################################################
