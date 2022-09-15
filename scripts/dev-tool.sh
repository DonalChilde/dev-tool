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
# https://linuxhint.com/bash_split_examples/
# https://unix.stackexchange.com/questions/86923/delete-subfolders-without-deleting-parent-folder

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
SCRIPT_NAME="dev-tool" # The script name without a file ending.
ENV_NAME=".$SCRIPT_NAME.env"
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
    echo "$ENV_NAME file not found. Using default settings."
fi

#################################################
#              Variables                        #
#################################################

###########Project variables#####################
PROJECT_DIR="${PROJECT_DIR:-$(realpath ".")}"
SOURCE_PATH="${SOURCE_PATH:-'$PROJECT_DIR/src'}"
TEST_PATH="${TEST_PATH:-'$PROJECT_DIR/tests'}"
TOP_PACKAGE="${TOP_PACKAGE:-'SET_PACKAGE_NAME'}" # Set the top level project package name

###########Python variables######################
VENV_PYTHON_VERSION="${VENV_PYTHON_VERSION:-3.10}"
VENV_LOCATION="${VENV_LOCATION:-$PROJECT_DIR/.venv}"
VENV_PYTHON3="$VENV_LOCATION/bin/python3"

###########Dependency variables##################
BUILD_DEPENDENCIES=${BUILD_DEPENDENCIES:-"pip setuptools wheel build pip-tools"}
read -a BUILD_DEP <<<$BUILD_DEPENDENCIES # Split the string, allows passing by .env
REQUIREMENTS_MAIN="${REQUIREMENTS_MAIN:-'$PROJECT_DIR/requirements.txt'}"
REQUIREMENTS_DEV="${REQUIREMENTS_DEV:-'$PROJECT_DIR/requirements-dev.txt'}"

#############Sphinx variables####################
DOC_BUILD_DIR=${DOC_BUILD_DIR:-"$PROJECT_DIR/docs/build"}
DOC_SRC_DIR=${DOC_SRC_DIR:-"$PROJECT_DIR/docs/source"}
BROWSER_PATH=${BROWSER_PATH:-"/opt/google/chrome/chrome"}

#############Distribution variables##############
TWINE_SECRETS=${TWINE_SECRETS:-"$PROJECT_DIR/secrets/twine.env"}
TWINE_TEST_SECRETS=${TWINE_TEST_SECRETS:-"$PROJECT_DIR/secrets/twine-test.env"}
DIST_DIR=${DIST_DIR:-"$PROJECT_DIR/dist"}

#################################################
#                   Clean                       #
#################################################

function clean() { ## Clean build,python, and test artifacts.
    clean:build
    clean:pyc
    clean:test
}

function clean-build() { ## Clean build artifacts.
    rm -fr $PROJECT_DIR/build/
    rm -fr $PROJECT_DIR/dist/
    rm -fr $PROJECT_DIR/.eggs/
    find $PROJECT_DIR -name '*.egg-info' -exec rm -fr {} +
    find $PROJECT_DIR -name '*.egg' -exec rm -f {} +
}

function clean-pyc() { ## Clean python aritfacts.
    find $PROJECT_DIR -name '*.pyc' -exec rm -f {} +
    find $PROJECT_DIR -name '*.pyo' -exec rm -f {} +
    find $PROJECT_DIR -name '*~' -exec rm -f {} +
    find $PROJECT_DIR -name '__pycache__' -exec rm -fr {} +
}

function clean-test() { ## Clean test artifacts.
    rm -fr $PROJECT_DIR/.tox/
    rm -f $PROJECT_DIR/.coverage
    rm -fr $PROJECT_DIR/htmlcov/
    rm -fr $PROJECT_DIR/.pytest_cache
    rm -fr $PROJECT_DIR/.mypy_cache
}

function clean-docs() { ## Clean the doc build directory.
    # Delete the contents of doc build directory, but leave parent dir.
    # https://unix.stackexchange.com/a/86950
    find $DOC_BUILD_DIR -mindepth 1 -maxdepth 1 -print0 | xargs -0 rm -rf

}

#################################################
#              Distribution                     #
#################################################

function dist-build() { ## builds source and wheel package.
    clean-build
    # The old way, with setuptools
    # $VENV_PYTHON3 $PROJECT_DIR/setup.py sdist
    # $VENV_PYTHON3 $PROJECT_DIR/setup.py bdist_wheel

    # The new way
    # Using pyproject.toml
    $VENV_PYTHON3 -m build
    ls -l dist
}

function dist-release() { ## Upload a release to PyPi.
    # https://twine.readthedocs.io/en/stable/
    echo "Preparing to upload to PyPi."
    echo "Did you:"
    echo "\t- Check for the correct branch?"
    echo "\t- Update the version number?"
    echo "\t- Update the documentation?"
    echo "\t- Run ALL THE TESTS?"
    echo "\t- Update the changelog?"
    echo "\t- Build a fresh dist/?"
    echo
    echo "Take ten seconds to be sure:"
    _countdown 10
    # https://stackoverflow.com/a/1885534/105844
    read -p "Are you sure? (Y/N)" -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        source $TWINE_SECRETS
        twine check $DIST_DIR/*
        twine upload $DIST_DIR/*
    fi
}

function dist-test-release() { ## Upload a release to TestPyPi.
    echo "Preparing to upload to TestPyPi"
    echo "Did you:"
    echo "\t- Check for the correct branch?"
    echo "\t- Update the version number?"
    echo "\t- Update the documentation?"
    echo "\t- Run ALL THE TESTS?"
    echo "\t- Update the changelog?"
    echo "\t- Build a fresh dist/?"
    echo
    echo "Take ten seconds to be sure:"
    _countdown 10
    # https://stackoverflow.com/a/1885534/105844
    read -p "Are you sure? (Y/N)" -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        source $TWINE_TEST_SECRETS
        twine check $DIST_DIR/*
        twine upload --repository testpypi $DIST_DIR/*
    fi
}

#################################################
#              Documentation                    #
#################################################

function docs-build() { ## Build documentation with Sphinx.
    # sphinx-apidoc makes an ugly format, see the Rich docs for a better manual example.
    rm -rf $DOC_SRC_DIR/apidoc/
    sphinx-apidoc -o $DOC_SRC_DIR/apidoc $SOURCE_PATH/$TOP_PACKAGE
    sphinx-build -b html $DOC_SRC_DIR $DOC_BUILD_DIR
}

function docs-serve() { ## Open docs in a web browser
    $BROWSER_PATH $DOC_BUILD_DIR/index.hmtl
}

#################################################
#               Formatting                      #
#################################################

function format-isort() { ## Takes Arguments. Run isort.
    printf "Running isort on %s\n" "${@}"
    $VENV_PYTHON3 -m isort "${@}"
}

function format-black() { ## Takes Arguments. Run isort.
    printf "Running black on %s\n" "${@}"
    $VENV_PYTHON3 -m black "${@}"
}

function format-diff-isort() { ## Takes Arguments. Run isort --diff.
    printf "Running isort --diff on %s\n" "${@}"
    $VENV_PYTHON3 -m isort "${@}" --diff
}

function format-diff-black() { ## Takes Arguments. Run isort --diff.
    printf "Running black --diff on %s\n" "${@}"
    $VENV_PYTHON3 -m black "${@}" --diff
}

function format() { ## isort and black on project.
    format-isort $SOURCE_PATH $TEST_PATH
    format-black $SOURCE_PATH $TEST_PATH
}

function format-diff() { ## isort --diff and black --diff on project.
    format-diff-isort $SOURCE_PATH $TEST_PATH
    format-diff-black $SOURCE_PATH $TEST_PATH
}

#################################################
#                Linting                        #
#################################################

function lint() { ## Run mypy and pylint on project.
    lint-mypy $SOURCE_PATH $TEST_PATH
    lint-pylint $SOURCE_PATH $TEST_PATH
}

function lint-mypy() { ## Takes Arguments. Run mypy.
    set +e             # Allow bash to continue if there are errors.
    printf "Running mypy on %s\n" "${@}"
    $VENV_PYTHON3 -m mypy "${@}"
}

function lint-pylint() { ## Takes Arguments. Run pylint.
    set +e               # Allow bash to continue if there are errors.
    printf "Running pylint on %s\n" "${@}"
    $VENV_PYTHON3 -m pylint "${@}"
}

#################################################
#                  Testing                      #
#################################################

function _pytest() {
    $VENV_PYTHON3 -m pytest "${@}"
}

function pytest() { ## Takes Arguments. Run test suite with pytest.
    _pytest $TEST_PATH "${@}"
}

function pytest-cov() { ## Takes arguments. Get test coverage with pytest-cov.
    _pytest $TEST_PATH --cov src/ --cov-report term-missing "${@}"
}

function tox() { ## Run tox.
    $VENV_PYTHON3 -m tox
}

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
    dep-build
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

function dep-build() { ## Upgrade the build dependencies.
    dep-upgrade "${BUILD_DEP[@]}"
}

function dep-install-main() { ## Install the main requirements
    dep-install $REQUIREMENTS_MAIN
}

function dep-install-dev() { ## Install the dev requirements
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
    date1=$(($(date +%s) + $1))
    while [ "$date1" -ge $(date +%s) ]; do
        echo -ne "$(date -u --date @$(($date1 - $(date +%s))) +%H:%M:%S)\r"
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
    python3 - <<EOF
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

function _function-list() {
    # A convenience function to generate a space delimited string of
    # all the functions in this script.
    python3 - <<EOF
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
    target_list = []
    for target, help in sorted(functions):
        target_list.append(target)
    print(" ".join(target_list))
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
    echo "BUILD_DEPENDENCIES=$BUILD_DEPENDENCIES"
    echo "BUILD_DEP=${BUILD_DEP[@]}"

}

function completions() { ## Generate a completion file. Accepts a directory for output. defaults to pwd.
    # Accepts a directory for output
    if [ "$#" -ne 1 ]; then
        dir_path="$PWD"
    else
        dir_path="$1"
    fi
    COMPLETION_COMMANDS="clean clean-build clean-docs clean-pyc clean-test completions dep-build dep-install dep-install-dev dep-install-main dep-upgrade dist-build dist-release dist-test-release docs-build docs-serve format format-black format-diff format-diff-black format-diff-isort format-isort generate-env help lint lint-mypy lint-pylint pytest pytest-cov settings tox venv-init venv-remove venv-reset venv-version"
    cat <<EOF >"$dir_path/$SCRIPT_NAME.completion"
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

function generate-env() { ## Generate an .env file. Accepts a directory for output. defaults to pwd.
    # Accepts a directory for output
    if [ "$#" -ne 1 ]; then
        dir_path="$PWD"
    else
        dir_path="$1"
    fi
    # Check if file exists, and approve overwrite.
    if [ -f "$dir_path/$ENV_NAME" ]; then
        echo "This will overwrite the current $ENV_NAME at:"
        echo "$dir_path/$ENV_NAME"
        read -p "Are you sure? (Y/N)" -n 1 -r
        echo # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo # continue with the rest of the function
        else
            echo "Declined to overwrite $ENV_NAME"
            exit 1
        fi
    fi
    # Ensure any parent directories are created.
    mkdir -p $dir_path && touch "$dir_path/$ENV_NAME"
    cat <<EOF >"$dir_path/$ENV_NAME"
# A settings file for $SCRIPT_NAME.sh

# Place this file in the script directory, or the pwd.
# The pwd is searched before the script directory, and
# the first file named $ENV_NAME is loaded.

###########Project variables#####################

# The project directory
# Not required to be set, if dev-tool.sh is 
# called from the project root directory each time.
#
# PROJECT_DIR="."

# The top directory for source files
#
# SOURCE_PATH="./src"

# The top directory for test files
#
# TEST_PATH="./tests"

# The project root package name
#   #####REQUIRED#####
# TOP_PACKAGE="<SET_PACKAGE_NAME>"

###########Python variables######################

# The Python version to be used in the creation of 
# virtual environments. must be installed on this machine.
# e.g. "3", "3.10", "3.10.4"
#
# VENV_PYTHON_VERSION="3"

# The location of the virtual environment. Used in the scripts
# invocation of most python commands.
#
# VENV_LOCATION="./.venv"






# The version of python used to create Virtual Environments
# This is useful for systems with more than one python installed.
#
# VENV_PYTHON_VERSION="3.10"

EOF

    echo "$ENV_NAME written to $(realpath $dir_path)"
}

# This idea is heavily inspired by: https://github.com/adriancooney/Taskfile
# Runs the help function if no arguments given to script.
TIMEFORMAT=$'\nTask completed in %3lR'
time "${@:-help}"
################### No code below this line #####################
