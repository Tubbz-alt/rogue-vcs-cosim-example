# rogue-vcs-cosim-example

<!--- ######################################################## -->

# Before you clone the GIT repository

1) Create a github account:
> https://github.com/

2) On the Linux machine that you will clone the github from, generate a SSH key (if not already done)
> https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/

3) Add a new SSH key to your GitHub account
> https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

4) Setup for large filesystems on github

```
$ git lfs install
```

5) Verify that you have git version 2.13.0 (or later) installed 

```
$ git version
git version 2.13.0
```

6) Verify that you have git-lfs version 2.1.1 (or later) installed 

```
$ git-lfs version
git-lfs/2.1.1
```

# Clone the GIT repository

```
$ git clone --recursive git@github.com:slaclab/rogue-vcs-cosim-example
```


<!--- ########################################################################################### -->

# How to install the Rogue With Anaconda:

> https://slaclab.github.io/rogue/installing/anaconda.html

<!--- ########################################################################################### -->

# PyDM Documentation:

> https://slaclab.github.io/pydm/

<!--- ########################################################################################### -->

# How to run the Rogue PyDM GUI with VCS firmware simulator

1) Start up two terminal

2) In the 1st terminal, launch the VCS simulation
```
$ source rogue-vcs-cosim-example/firmware/setup_env_slac.sh
$ cd rogue-vcs-cosim-example/firmware/simulations/CosimExampleTb/
$ make vcs
$ cd ../../build/CosimExampleTb/CosimExampleTb_project.sim/sim_1/behav/
$ source setup_env.sh
$ ./sim_vcs_mx.sh
$ ./simv -gui &
```

3) When the VCS GUI pops up, start the simulation run

4) In the 2nd terminal, launch the PyDM GUI in simulation mode
```
$ cd rogue-vcs-cosim-example/software
$ source setup_env_template.sh
$ python scripts/DevGui.py
```

<!--- ######################################################## -->
