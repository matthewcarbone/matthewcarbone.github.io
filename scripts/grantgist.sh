#!/bin/bash

now=$(date)

export HOME="/home/mcarbone"
source "$HOME/.api_keys"
export PATH="$PATH:/home/mcarbone/.local/bin:/usr/local/bin:/usr/bin"

d=$(dirname "$0")
cd "$d/.." || exit 1
echo "Running from $d"
pwd

echo "home variable is $HOME"

uvx --from git+https://github.com/matthewcarbone/Composer@v0.0.4 grantgist ai=azure hydra.verbose=true
mv ~/.composer-home/grantgist/summaries/*.md _grantgists || exit 0
git add _grantgists/*.md
git commit -m "Automatic grantgist run: $now"
