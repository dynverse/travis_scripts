#!/bin/bash

set -e

docker build -t dynverse/travis_test_build .

R --no-save << 'HERE'
library(dynwrap)
library(dyntoy)

source("example.R")

config <- container_docker()

meth <- create_ti_method_with_container("dynverse/travis_test_build", config = config)()

traj <- infer_trajectory(data, meth, params)
HERE
