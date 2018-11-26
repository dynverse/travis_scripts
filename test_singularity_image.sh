#!/bin/bash

set -e
set -o xtrace

# append github pat to recipe
if [ ! -z "$GITHUB_PAT" ]; then 
  echo "GITHUB_PAT found!"
  sed -i "s#^RUN #&GITHUB_PAT='$GITHUB_PAT' #" Dockerfile
  R -e 'babelwhale::convert_dockerfile_to_singularityrecipe("Dockerfile", "Singularity")'
else
  echo "No GITHUB_PAT found :("
fi

# build image
sudo singularity build travis_test_build.simg Singularity

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

config <- babelwhale::create_singularity_config(cache_dir = "images/", use_cache = TRUE)
babelwhale::set_default_config(config)

meth <- create_ti_method_container("dynverse/travis_test_build")()

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
  print(as.data.frame(eval$summary))
}
HERE
