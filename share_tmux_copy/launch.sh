#!/usr/bin/env bash

export MISE_DATA_DIR=$HOME/media/data/mise
eval $(mise activate --shims bash)

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"
pwd

bundle exec ruby server.rb 8001
