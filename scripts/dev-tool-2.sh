#!/usr/bin/env bash

# Master copy located at https://github.com/DonalChilde/dev-tool
# curl -O https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool-2.sh
# Version 0.1.0
# 2022-09-10 14:26:58


# Ideas shamelessly lifted from:
# https://github.com/nickjj/docker-flask-example/blob/main/run
# https://github.com/audreyfeldroy/cookiecutter-pypackage/blob/master/%7B%7Bcookiecutter.project_slug%7D%7D/Makefile
# https://superuser.com/questions/611538/is-there-a-way-to-display-a-countdown-or-stopwatch-timer-in-a-terminal
# https://www.gnu.org/software/gnuastro/manual/html_node/Bash-TAB-completion-tutorial.html
# https://tldp.org/LDP/abs/html/tabexpansion.html
# https://github.com/scop/bash-completion
# https://github.com/adriancooney/Taskfile



# Add custom functions in the Custom Function section
# Functions beginning with a letter or number will be included in the generated help output.
# On the function definition line, text following ## will be treated as help text.
# Update the completion generatior with appropriate completion info.
# Update the .env generator if desired.


# -e Exit immediately if a pipeline returns a non-zero status.
# -u Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error when performing parameter expansion.
# -o pipefail If set, the return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status, or zero if all commands in the pipeline exit successfully.
set -euo pipefail


#################################################
#             script-base Variables             #
#################################################
SCRIPT_NAME="dev-tool-2" # The script name without a file ending.
ENV_NAME=".env-$SCRIPT_NAME"
SCRIPT_DIR=$(realpath $(dirname $0))
SCRIPT_PATH=$(realpath $0)

#################################################
#               import .env variables           #
#################################################

# https://stackoverflow.com/a/30969768/105844

if [ -f "$PWD/$ENV_NAME" ]; then
    # Found an .env file in the present working directory
    ENV_PATH="$PWD/$ENV_NAME"
    set -o allexport
    source $ENV_PATH
    set +o allexport
    echo "Settings loaded from $ENV_PATH"
elif [ -f "$SCRIPT_DIR/$ENV_NAME" ]; then
    # Found an .env file in the script directory
    ENV_PATH="$SCRIPT_DIR/$ENV_NAME"
    set -o allexport
    source $ENV_PATH
    set +o allexport
    echo "Settings loaded from $ENV_PATH"
else
    echo ".env file not found."
fi

#################################################
#              Variables                        #
#################################################

PROJECT_DIR="${PROJECT_DIR:-$(realpath ".")}"
SOURCE_PATH="${SOURCE_PATH:-'$PROJECT_DIR/src'}"
TEST_PATH="${TEST_PATH:-'$PROJECT_DIR/tests'}"
VENV_PYTHON_VERSION="${VENV_PYTHON_VERSION:-3.10}"
VENV_LOCATION="${VENV_LOCATION:-$PROJECT_DIR/.venv}"
PYTHON3_PATH="/bin/python3"
VENV_PYTHON3=$VENV_LOCATION$PYTHON3_PATH
BASE_DEPENDENCIES=${BASE_DEPENDENCIES:-"pip setuptools wheel pip-tools"}
read -a BASE_DEP <<< $BASE_DEPENDENCIES # Split the string, allows passing by .env
REQUIREMENTS_MAIN="${REQUIREMENTS_MAIN:-'$PROJECT_DIR/requirements.txt'}"
REQUIREMENTS_DEV="${REQUIREMENTS_dev:-'$PROJECT_DIR/requirements_dev.txt'}"
# https://linuxhint.com/bash_split_examples/

#################################################
#               Custom functions                #
#################################################

#################################################
#          Virtual Environments                 #
#################################################

function venv-init() { ## Make a new project venv.
    python${PYTHON_VENV_VERSION} -m venv ${VENV_LOCATION}
    if [ -f "$VENV_PYTHON3" ]; then
        printf "Installed a virtual environment at\n$(realpath $VENV_LOCATION)/\nusing $($VENV_PYTHON3 --version)."
    else
        echo "Failed to install a virtual environment, python3 not found at $VENV_PYTHON3."
        exit 1
    fi
}

function venv-remove() { ## Delete the project venv.
    if [ -f "$VENV_PYTHON3" ]; then
        printf "Removing the virtual environment at\n$(realpath $VENV_LOCATION)/"
        printf "\nClose any terminal windows that were using this venv.\n"
        rm -r ${VENV_LOCATION}/
    else
        echo "virtual environment not found at $VENV_LOCATION."
        exit 1
    fi
    
}

function venv-reset() { ## Remove and reinstall the project venv.
    venv-remove
    venv-init
}

function venv-version() { ## Check the virtual environment python version.
    if [ -f "$VENV_PYTHON3" ]; then
        printf "Found $($VENV_PYTHON3 --version) at $(realpath $VENV_PYTHON3)"
    else
        printf "No python3 found at $(realpath $VENV_PYTHON)"
    fi
}

#################################################
#          Dependency management                #
#################################################

function _pip3() {
    $VENV_PYTHON3 -m pip "${@}"
}

function dep-install() { ## Install packages using pip.
    _pip3 install "${@}"
}

function dep-upgrade() { ## Upgrade packages using pip.
    _pip3 install "${@}" --upgrade
}

function dep-init() { ## Upgrade the base build dependencies.
    dep-upgrade "${BASE_DEP[@]}"
}

function dep-install-main() { ## Install the main requirements
    dep-install $REQUIREMENTS_MAIN
}

function dep-install-dev() {
    dep_install $REQUIREMENTS_DEV
}

function dep-compile() {
    echo "# pip-tool functions"
}

#################################################
#               Common Functions                #
#################################################

function _countdown() {
    # https://superuser.com/questions/611538/is-there-a-way-to-display-a-countdown-or-stopwatch-timer-in-a-terminal
    # Display a countdown clock. 
    # $1 = int seconds
    date1=$((`date +%s` + $1));
    while [ "$date1" -ge `date +%s` ]; do
        echo -ne "$(date -u --date @$(($date1 - `date +%s`)) +%H:%M:%S)\r";
        sleep 0.1
    done
}

function help() { ## Get script help.
    printf "\n------ $SCRIPT_NAME Help ------"
    printf "\nA dev-tool script."
    printf "\nFor more information visit https://github.com/DonalChilde/dev-tool"
    printf "\nScript path: $SCRIPT_PATH"
    printf "\nWorking Directory: $PWD"
    printf "\nThis script expects to be run from the project root directory.\n"
    _help
}

function _help() { ## Uses python to parse out function name and help text.
    python3 - << EOF
from pathlib import Path
from operator import itemgetter
import re
script_path = Path("$SCRIPT_PATH")
with open(script_path) as file:
    functions = []
    for line in file:
        match = re.match(r'^function\s*([a-zA-Z0-9\:-]*)\(\)\s*{\s*##\s*(.*)', line)
        if match is not None:
            functions.append(match.groups())
    for target, help in sorted(functions):
        print("  {0:20}    {1}".format(target,help))
EOF
}

function settings() { ## echo settings to terminal.

echo "PWD=$PWD"
echo "SCRIPT_NAME=$SCRIPT_NAME"
echo "ENV_NAME=$ENV_NAME"
echo "SCRIPT_PATH=$SCRIPT_PATH"

echo "PROJECT_DIR=$PROJECT_DIR"
echo "SOURCE_PATH=$SOURCE_PATH"
echo "TEST_PATH=$TEST_PATH"
echo "VENV_PYTHON_VERSION=$VENV_PYTHON_VERSION"
echo "VENV_LOCATION=$VENV_LOCATION"
echo "VENV_PYTHON3=$VENV_PYTHON3"
echo "REQUIREMENTS_MAIN=$REQUIREMENTS_MAIN"
echo "REQUIREMENTS_DEV=$REQUIREMENTS_DEV"
echo "BASE_DEPENDENCIES=$BASE_DEPENDENCIES"
echo "BASE_DEP=${BASE_DEP[@]}"

}

function completions() { ## Generate a completion file
COMPLETION_COMMANDS="help completions settings generate-env"
cat << EOF > $SCRIPT_NAME.completion
# An example of bash completion
# File name: $SCRIPT_NAME.completion

# Installation:
# Place this file in a directory, e.g ~/.bash_completions
# Add the following command to ~/.bashrc
# source ~/.bash_completions/$SCRIPT_NAME.completion

# Reference
# https://www.gnu.org/software/gnuastro/manual/html_node/Bash-TAB-completion-tutorial.html
# https://tldp.org/LDP/abs/html/tabexpansion.html
# https://github.com/scop/bash-completion

_$SCRIPT_NAME() { #  By convention, the function name is the command with an underscore.

  # \$1 is the command

  # Pointer to current completion word.
  # By convention, it's named "cur" but this isn't strictly necessary.
  local cur="\$2"
  
  # Pointer to previous completion word.
  # By convention, it's named "prev" but this isn't strictly necessary.
  local prev="\$3"

  # Array variable storing the possible completions.
  COMPREPLY=( \$( compgen -W "$COMPLETION_COMMANDS" -- "\$cur" ) )

  # More complicated completions can be made using
  # if/else or case logic, branching by previous word.

  return 0
}

# Use a function to get completions for the specified command
complete -F _$SCRIPT_NAME $SCRIPT_NAME.sh
EOF

}

function generate-env() {
cat << EOF > $ENV_NAME
# A settings file for $SCRIPT_NAME.sh

# Place this file in the script directory, or the pwd.
# The pwd is searched before the script directory, and
# the first file named .env_$SCRIPT_NAME is loaded.

# The project directory
# Not required to be set, if dev-tool.sh is 
# called from the project directory each time.
#
# PROJECT_DIR=$(realpath ".")

# The top directory for source files
#
# SOURCE_PATH="$PROJECT_DIR/src"

# The top directory for test files
#
# TEST_PATH="$PROJECT_DIR/tests"

# The version of python used to create Virtual Environments
# This is useful for systems with more than one python installed.
#
# VENV_PYTHON_VERSION="3.10"

EOF
}



# This idea is heavily inspired by: https://github.com/adriancooney/Taskfile
# Runs the help function if no arguments given to script.
TIMEFORMAT=$'\nTask completed in %3lR'
time "${@:-help}"
################### No code below this line #####################
