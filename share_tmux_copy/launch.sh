#!/usr/bin/env bash

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"

echo Current is $(pwd), PATH is ${PATH}
echo ls is $(ls -a)
echo use bundle: $(which bundle) $(bundle -v)
echo use ruby: $(bundle exec ruby -v) at $(bundle exec which ruby)
echo Gems: $(bundle exec gem list)

bundle exec ruby server.rb 8001
