#!/bin/bash

set -e

docker build -t dynverse/travis_test_build .

R --no-save << 'HERE'
library(dynwrap)
library(dyntoy)

source("example.R")

config <- container_docker()

meth <- create_ti_method_with_container("dynverse/travis_test_build", config = config)()

if (meth$id == "error") {
  tryCatch({
    traj <- infer_trajectory(data, meth, params)
    stop("Expected error")
  }, error = function() {
    cat("All is well!")
  }
} else {
  traj <- infer_trajectory(data, meth, params, verbose = TRUE)
}
HERE
