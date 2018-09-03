#!/bin/bash

set -e

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

