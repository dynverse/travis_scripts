##############################
##             R            ##
##############################
install_cran() {
  local package=$1
  R --no-save << HERE
options(repos = "https://cloud.r-project.org/")
if ("$package" %in% rownames(installed.packages())) {
  update.packages(oldPkgs = "$package", ask = FALSE) 
} else {
  install.packages("$package")
}
HERE
}

install_github() {
  local repo=$1
  R -e "setRepositories(ind = 1:4); devtools::install_github('$repo')"
}

install_github_withdeps() {
  local repo=$1
  R -e "setRepositories(ind = 1:4); devtools::install_github('$repo', dep = TRUE, upgrade = TRUE)"
}
install_withdeps() {
  R -e 'setRepositories(ind = 1:4); devtools::install(dependencies = TRUE, upgrade = TRUE)'
}
use_dynverse_devel() {
  sedi () { sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@" ; }
  if [ `git branch | grep '* master' | wc -l` == 0 ]; then
    sedi 's#\(dynverse/[^, @]*\)#\1@devel#' 'DESCRIPTION'
  fi
}
##############################
##          DOCKER          ##
##############################
update_docker() {
  sudo apt-get update -y
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

##############################
##           HDF5           ##
##############################
install_hdf5() {
  export HDF5_DIR=$HOME/.cache/hdf5
  echo $HDF5_DIR
  export HDF5_VERSION=1.10.1
  echo $HDF5_VERSION

  if [ "$TRAVIS_OS_NAME" == "osx" ]; then # use homebrew version
    echo "installing hdf5"
    brew update
    brew install hdf5 || true
    echo "brew install finished"
  else 
    if [ -z ${HDF5_DIR+x} ]; then
        echo "Using OS HDF5"
    else
        echo "Using downloaded HDF5"
        if [ -f $HDF5_DIR/lib/libhdf5.so ]; then
          echo "using cached build"
        else
      pushd /tmp
      wget https://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-$HDF5_VERSION/src/hdf5-$HDF5_VERSION.tar.gz
      tar -xzvf hdf5-$HDF5_VERSION.tar.gz
      pushd hdf5-$HDF5_VERSION
      chmod u+x autogen.sh
      ./configure --prefix $HDF5_DIR
      make -j 2
      make install
      popd
      popd
        fi
    fi
    sudo cp $HDF5_DIR/bin/* /usr/bin/
    sudo cp $HDF5_DIR/lib/* /usr/lib/
    sudo cp $HDF5_DIR/include/* /usr/include/
  fi

  install_cran hdf5r
}

##############################
##         PHANTOMJS        ##
##############################
install_phantomjs() {
  # https://rstudio.github.io/shinytest/articles/ci.html

  export PHANTOMJS_DIR=$HOME/.cache/phantomjs
  export PHANTOMJS_VERSION=2.1.1
  phantomjs --version
  export PATH=$PHANTOMJS_DIR/phantomjs-$PHANTOMJS_VERSION-linux-x86_64/bin:$PATH
  hash -r
  phantomjs --version

  if [ $(phantomjs --version) != $PHANTOMJS_VERSION ]; then 
    echo "installing phantomjs"
    rm -rf $PHANTOMJS_DIR
    mkdir -p $PHANTOMJS_DIR
    pushd /tmp
    wget https://github.com/Medium/phantomjs/releases/download/v$PHANTOMJS_VERSION/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2
    tar -xvf phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 -C $PHANTOMJS_DIR
    popd
    hash -r
  fi
  phantomjs --version
}

##############################
##        PYTHON 3.6        ##
##############################
install_python_3_6() {
  local bucket="travis-python-archives"
  local vers="3.6"
  local lang="python"
  local PYENV_PATH_FILE="/etc/profile.d/pyenv.sh"
  local archive_basename="${lang}-${vers}"
  local archive_filename="${archive_basename}.tar.bz2"
  local travis_host_os=$(lsb_release -is | tr 'A-Z' 'a-z')
  local travis_rel_version=$(lsb_release -rs)
  local archive_url=https://s3.amazonaws.com/${bucket}/binaries/${travis_host_os}/${travis_rel_version}/$(uname -m)/${archive_filename}

  echo "Downloading archive: ${archive_url}"
  curl -sSf -o ${archive_filename} ${archive_url}
  sudo tar xjf ${archive_filename} --directory /
  rm ${archive_filename}
  echo 'export PATH=/opt/python/${vers}/bin:$PATH' | sudo tee -a ${PYENV_PATH_FILE} &>/dev/null
  export PATH="/opt/python/${vers}/bin:$PATH"

  sudo /opt/python/${vers}/bin/pip3.6 install --upgrade pip setuptools wheel
  python3 -V
  pip3 -V
}

##############################
##      SINGULARITY 2.5     ##
##############################
install_singularity_2_5() {
  SINGULARITY_VERSION=2.5.2

  export SINGULARITY_DIR="$HOME/.cache/singularity-$SINGULARITY_VERSION"
  echo $SINGULARITY_DIR

  if [ "$TRAVIS_OS_NAME" == "osx" ]; then # use homebrew version
    echo "Panic!"
  else
    # install build requirements
    sudo apt-get update
    sudo apt-get install -y squashfs-tools libarchive-dev build-essential

    if [ -f $SINGULARITY_DIR/bin/singularity ]; then
      echo "using cached build"
    else
      # download singularity
      pushd /tmp
      wget "https://github.com/singularityware/singularity/releases/download/${SINGULARITY_VERSION}/singularity-${SINGULARITY_VERSION}.tar.gz"
      tar -xvf "singularity-${SINGULARITY_VERSION}.tar.gz" -C "$HOME/.cache"
      popd
      
      # build singularity
      pushd $SINGULARITY_DIR
      ./configure --prefix=/usr/local
      make -j 2
      popd
    fi

    # install Singularity
    pushd $SINGULARITY_DIR
    sudo make install
    popd
  fi
}
