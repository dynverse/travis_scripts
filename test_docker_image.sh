#!/bin/bash

set -e

docker build -t dynverse/travis_test_build .

R --no-save << 'HERE'
library(dynwrap)
library(dyntoy)

source("example.R")

config <- dynwrap::container_create_docker_config()
dynwrap::container_set_default_config(config)

meth <- create_ti_method_with_container("dynverse/travis_test_build")()

if (meth$id == "error") {
  sink("/dev/null")
  out <- 
    tryCatch({
      sink("/dev/null")
      traj <- infer_trajectory(data, meth, params)
      TRUE
    }, error = function(e) {
      FALSE
    })
  sink()
  sink()
  if (out) stop("Expected an error!") else cat("All is well!\n")
} else {
  traj <- infer_trajectory(data, meth, params, verbose = TRUE)
}
HERE
