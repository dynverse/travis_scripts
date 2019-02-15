update_docker() {
  sudo apt-get install --only-upgrade docker-ce -y
}

build_docker() {
  sudo docker build --build-arg GITHUB_PAT=${GITHUB_PAT} -t $TRAVIS_REPO_SLUG:v$VERSION .
  docker tag $TRAVIS_REPO_SLUG:v$VERSION $TRAVIS_REPO_SLUG:latest
}

test_docker() {
R --no-save << HERE
library(dynwrap)
library(dyntoy)
library(dyneval)
library(babelwhale)

source("example.R")

config <- babelwhale::create_docker_config()
babelwhale::set_default_config(config)

meth <- create_ti_method_container("$TRAVIS_REPO_SLUG")()

metrics <- c("correlation", "him", "F1_branches", "featureimp_wcor")

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
}

push_docker() {
  if [[ "$TRAVIS_BRANCH" == "master" ]]; then
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
    docker push $TRAVIS_REPO_SLUG
  fi
}
