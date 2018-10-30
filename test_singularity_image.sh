#!/bin/bash

set -e

# append github pat to singularity recipe, a github pat is available in the environment
if [ ! -z "$GITHUB_PAT" ]; then 
  echo "%environment" >> Singularity
  echo "export GITHUB_PAT=$GITHUB_PAT" >> Singularity
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
  print(as.data.frame(eval$summary))
}
HERE
