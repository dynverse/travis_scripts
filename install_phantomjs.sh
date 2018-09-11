#!/bin/bash

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
