#!/usr/bin/env bash

export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR=$HOME/.nvm;
export CALLDIR="$(pwd)"

if [[ $OSTYPE == darwin* ]]; then
  source $NVM_DIR/nvm.sh;
fi

scriptname=$( basename -- "$0"; )
scriptdir=$( dirname -- "$0"; )
#echo "The script you are running has basename $scriptname, dirname $scriptdir";
#echo "The present working directory is $( pwd; )";


cd "$scriptdir" || exit

# cmd=("$HOME/.nvm/versions/node/v16.20.1/bin/npx" "elm-pages@3.0.3" "run" "Lx" "--" "$@")
cmd=("npx" "elm-pages" "run" "./src/Lx.elm" "--" "$@")

# elm-pages script currently has some of its own debugging output that we don't want, given
# we implement our own custom logging interface (see helpers.ts:logDebug)
# run the command and filter out lines ending in timing information and HTTP fetch lines
yes | ${cmd[*]} | grep --color=always --line-buffered -v -E 'BackendTask\.Custom\.run|^fetch'

# Take the exit status of the 2nd command in the previous pipeline
pstat=(${PIPESTATUS[@]})
cmd_exit_status=${pstat[1]}

exit "$cmd_exit_status"
