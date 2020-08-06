# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Remove the image directory (not used in simulation
exec rm -rf $::DIR_PATH/images

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules/surf

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb"

# Set the top level synth_1 and sim_1
set_property top {AxiVersion} [get_filesets sources_1]
set_property top {CosimExampleTb} [get_filesets sim_1]
