#!/bin/bash

set -e

# # changing permissions to reflect singularityhub
# sudo chmod go-rwx -R .
# sudo chown root.root -R .

# build image
sudo singularity build travis_test_build.simg Singularity

# # revert permissons to previous state (sortof)
# sudo chmod 777 -R .
# sudo chown travis.travis -R .

# move image to correct subdirectory
mkdir -p images/dynverse
mv travis_test_build.simg images/dynverse

# test image
R --no-save << 'HERE'
library(dynwrap)
library(dyntoy)
library(dyneval)
library(babelwhale)

source("example.R")

config <- babelwhale::create_docker_config()
babelwhale::set_default_config(config)

meth <- create_ti_method_with_container("dynverse/travis_test_build")()

metrics <- c("correlation", "edge_flip", "him", "F1_branches", "featureimp_cor", "featureimp_wcor")

if (meth$id == "error") {
  sink("/dev/null")
  out <- 
    tryCatch({
      sink("/dev/null")
      eval <- dyneval::evaluate_ti_method(data, meth, params)
      TRUE
    }, error = function(e) {
      FALSE
    })
  sink()
  sink()
  if (out) stop("Expected an error!") else cat("All is well!\n")
} else {
  eval <- dyneval::evaluate_ti_method(data, meth, params, metrics, verbose = TRUE)
  print(eval$summary)
}
HERE
