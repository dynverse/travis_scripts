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

source("example.R")

options("dynwrap_run_environment" = "singularity", "dynwrap_singularity_images_folder" = paste0(getwd(), "/images/"))

meth <- create_ti_method_with_container("dynverse/travis_test_build")()

if (meth$id == "error") {
  tryCatch({
    traj <- infer_trajectory(data, meth, params)
    stop("Expected error")
  }, error = function() {
    cat("All is well!")
  })
} else {
  traj <- infer_trajectory(data, meth, params, verbose = TRUE)
}
HERE
