##############################
##             R            ##
##############################
install_cran() {
  for package in "$@"; do
  R --no-save << HERE
options(repos = c(CRAN = "http://cran.rstudio.com"))
if ("$package" %in% rownames(installed.packages())) {
  update.packages(oldPkgs = "$package", ask = FALSE) 
} else {
  install.packages("$package")
}
HERE
  done
}

install_github() {
  for repo in "$@"; do
    R -e "setRepositories(ind = 1:4); remotes::install_github('$repo')"
  done
}

install_bioc() {
  for package in "$@"; do
    R -e "setRepositories(ind = 1:4); remotes::install_bioc('$package')"
  done
}

install_github_withdeps() {
  for repo in "$@"; do
    R -e "setRepositories(ind = 1:4); remotes::install_github('$repo', dep = TRUE, upgrade = TRUE)"
  done
}
install_withdeps() {
  R -e 'setRepositories(ind = 1:4); devtools::install(dependencies = TRUE, upgrade = TRUE)'
}
use_dynverse_devel() {
  sedi () { sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@" ; }
  if [ "$TRAVIS_BRANCH" != "master" ] ; then
    sedi 's#\(dynverse/[^, @]*\)\([, ]*\)$#\1@devel\2#' 'DESCRIPTION'
  fi
  cat DESCRIPTION
}
##############################
##          DOCKER          ##
##############################
update_docker() {
  sudo apt-get update -y
  sudo apt-get install --only-upgrade docker-ce -y
}

test_docker_variables() {
  if [ -z "$GITHUB_PAT" ]; then
    echo "Warning: variable GITHUB_PAT not found. It is strongly recommended to set configure a GITHUB_PAT."
  fi

  if [ -z "$REPO" ]; then
    echo "variable REPO not found, defaulting to TRAVIS_REPO_SLUG=$TRAVIS_REPO_SLUG."
    export REPO=$TRAVIS_REPO_SLUG
  fi
  
  if [ -z "$VERSION" ]; then
    echo "Error: variable VERSION not found."
    exit 1
  fi
}

build_docker() {
  test_docker_variables
  sudo docker build --build-arg GITHUB_PAT=$GITHUB_PAT -t $REPO:$TRAVIS_BRANCH .
  if [[ "$TRAVIS_BRANCH" == "master" ]]; then
    docker tag $REPO:$TRAVIS_BRANCH $REPO:v$VERSION
  fi
}

test_docker() {
  test_docker_variables
  Rscript example.sh /tmp/example.h5
  if [ "$REPO" != "dynverse/ti_error" ]; then 
    sudo docker run -v /tmp:/mnt $REPO:$TRAVIS_BRANCH --dataset /mnt/example.h5 --output /mnt/output.h5 --verbosity 3
    Rscript -e 'names(dynwrap::calculate_trajectory_dimred(dynutils::read_h5("/tmp/output.h5")))'
    sudo rm /tmp/example.h5 /tmp/output.h5
  fi
}

push_docker() {
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "Error: variable DOCKER_USERNAME not found."
    exit 1
  fi
  if [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: variable DOCKER_PASSWORD not found."
    exit 1
  fi
  docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
  docker push $REPO
}

##############################
##           HDF5           ##
##############################
install_hdf5() {
  if [ -z "$HDF5_VERSION" ]; then
    export HDF5_VERSION=1.10.1
  fi

  if [ "$TRAVIS_OS_NAME" == "osx" ]; then # use homebrew version
    echo "installing hdf5"
    brew update
    brew install hdf5 || true
    echo "brew install finished"
  else 
    echo "Downloading and installing HDF5 $HDF5_VERSION"
    TMP_DIR=`mktemp -d`
    pushd $TMP_DIR
    wget https://github.com/dynverse/travis_hdf5/raw/v$HDF5_VERSION/build.tar.gz
    sudo tar -xvzf build.tar.gz -C /usr
    popd

    rm -rf $TMP_DIR
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
