#!/bin/bash

set -e
set -o xtrace

# append github pat to dockerfile
if [ ! -z "$GITHUB_PAT" ]; then 
  echo "GITHUB_PAT found!"
  sed -i "s#^RUN #&GITHUB_PAT='$GITHUB_PAT' #" Dockerfile
else
  echo "No GITHUB_PAT found :("
fi

docker build -t dynverse/travis_test_build .

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
  print(as.data.frame(eval$summary))
}
HERE
