#!/bin/bash

set -e

# changing permissions to reflect singularityhub
sudo chmod go-rwx -R .
sudo chown root.root -R .

# build image
sudo singularity build travis_test_build.simg Singularity

# revert permissons to previous state (sortof)
sudo chmod 777 -R .
sudo chown travis.travis -R .

# move image to correct subdirectory
mkdir -p images/dynverse
mv travis_test_build.simg images/dynverse

# test image
R --no-save << 'HERE'
library(dynwrap)
library(dyntoy)

source("example.R")

config <- container_singularity(prebuild = TRUE, images = "images/")

meth <- create_ti_method_with_container("dynverse/travis_test_build", config = config)()

traj <- infer_trajectory(data, meth, params)
HERE
