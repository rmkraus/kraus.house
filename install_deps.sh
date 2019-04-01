#!/bin/bash

cd $(basename $0)

sudo yum install -y \
    @development-tools \
    gcc-c++ \
    zlib-static \
    ruby-devel \
    ruby \
    jekyll \
    rubygem-bundler

bundle install --path vendor/bundle
