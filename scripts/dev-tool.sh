#!/usr/bin/env bash

# Master copy located at https://github.com/DonalChilde/dev-tool
# curl -O https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool.sh
# or
# curl --create-dirs -O --output-dir ./scripts https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool.sh
# Version 0.2.0
# 2022-09-22T22:37:44Z

# Ideas shamelessly lifted from:
# https://github.com/nickjj/docker-flask-example/blob/main/run
# https://github.com/audreyfeldroy/cookiecutter-pypackage
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
# Set the top level project package name
# This value is only used to generate Sphinx documentation,
# so script does not automatically fail if unset.
TOP_PACKAGE="${TOP_PACKAGE:-'SET_PACKAGE_NAME'}"

###########Python variables######################
VENV_PYTHON_VERSION="${VENV_PYTHON_VERSION:-3.10}"
VENV_LOCATION="${VENV_LOCATION:-$PROJECT_DIR/.venv}"
VENV_PYTHON3="$VENV_LOCATION/bin/python3"

###########Dependency variables##################
# BUILD_DEPENDENCIES=${BUILD_DEPENDENCIES:-"pip setuptools wheel build pip-tools"}
# read -a BUILD_DEP <<<$BUILD_DEPENDENCIES # Split the string, allows passing by .env
REQUIREMENTS_MAIN="${REQUIREMENTS_MAIN:-$PROJECT_DIR/requirements/main.txt}"
REQUIREMENTS_DEV="${REQUIREMENTS_DEV:-$PROJECT_DIR/requirements/dev.txt}"
# REQUIREMENTS_BUILD="${REQUIREMENTS_BUILD:-$PROJECT_DIR/requirements/build.txt}"
# REQUIREMENTS_DOCS="${REQUIREMENTS_DOCS:-$PROJECT_DIR/requirements/docs.txt}"
# REQUIREMENTS_VSCODE="${REQUIREMENTS_VSCODE:-$PROJECT_DIR/requirements/vscode.txt}"
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
#          Dependency management                #
#################################################

function _pip3() {
    $VENV_PYTHON3 -m pip "${@}"
}

function deps-install() { ## Install packages using pip.
    _pip3 install "${@}"
}

function deps-outdated() { ## List outdated packages.
    _pip3 list --outdated
}

function deps-upgrade() { ## Upgrade packages using pip.
    _pip3 install "${@}" --upgrade
}

function deps-install-build() { ## Install the build dependencies.
    deps-install $REQUIREMENTS_BUILD
}

function deps-install-main() { ## Install the main requirements
    deps-install $REQUIREMENTS_MAIN
}

function deps-install-dev() { ## Install the dev requirements
    deps_install $REQUIREMENTS_DEV
}

function deps-install-editable() { ## Install the project in editable mode.
    deps-install -e $PROJECT_DIR
    _pip3 check
}

function deps-init() { ## Install all dependencies
    rm -rf $PROJECT_DIR/.tox
    deps-upgrade -r $REQUIREMENTS_MAIN -r $REQUIREMENTS_DEV #-r $REQUIREMENTS_BUILD -r $REQUIREMENTS_DOCS -r $REQUIREMENTS_VSCODE
    deps-install-editable

}

function deps-compile() { ## Pin dependencies from pyproject.toml into the requirements.txt files.
    # $VENV_PYTHON3 -m piptools compile --allow-unsafe --build-isolation --generate-hashes --extra documentation --upgrade --resolver backtracking -o $REQUIREMENTS_DOCS $PROJECT_DIR/pyproject.toml
    # $VENV_PYTHON3 -m piptools compile --allow-unsafe --build-isolation --generate-hashes --extra vscode --upgrade --resolver backtracking -o $REQUIREMENTS_VSCODE $PROJECT_DIR/pyproject.toml
    # $VENV_PYTHON3 -m piptools compile --allow-unsafe --build-isolation --generate-hashes --extra build --upgrade --resolver backtracking -o $REQUIREMENTS_BUILD $PROJECT_DIR/pyproject.toml
    $VENV_PYTHON3 -m piptools compile --allow-unsafe --build-isolation --generate-hashes --upgrade --resolver backtracking -o $REQUIREMENTS_MAIN $PROJECT_DIR/pyproject.toml
    $VENV_PYTHON3 -m piptools compile --allow-unsafe --build-isolation --generate-hashes --extra dev --upgrade -o $REQUIREMENTS_DEV $PROJECT_DIR/pyproject.toml
}

function deps-sync() { ## Use piptools sync to set available packages in venv
    $VENV_PYTHON3 -m piptools sync $REQUIREMENTS_MAIN $REQUIREMENTS_DEV $REQUIREMENTS_BUILD
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
#              Source Control                   #
#################################################

function _pre-commit() {
    $VENV_PYTHON3 -m pre_commit
}

function scm-precommit-update() { ## Run pre-commit autoupdate
    _pre-commit autoupdate
}

function scm-precommit-install() { ## Install pre-commit
    _pre-commit install
}

function scm-precommit-run() { ## Run precommit on all files
    _pre-commit run --all-files
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

function venv-init() { ## Make a new project venv, with updated pip, pip-tools, and setuptools.
    python${VENV_PYTHON_VERSION} -m venv ${VENV_LOCATION}
    if [ -f "$VENV_PYTHON3" ]; then
        printf "Installed a virtual environment at\n$(realpath $VENV_LOCATION)/\nusing $($VENV_PYTHON3 --version)."
        deps-upgrade pip setuptools pip-tools
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
    COMPLETION_COMMANDS="clean clean-build clean-docs clean-pyc clean-test completions deps-compile deps-init deps-install deps-install-build deps-install-dev deps-install-editable deps-install-main deps-outdated deps-sync deps-upgrade dist-build dist-release dist-test-release docs-build docs-serve format format-black format-diff format-diff-black format-diff-isort format-isort generate-env help lint lint-mypy lint-pylint pytest pytest-cov scm-precommit-install scm-precommit-run scm-precommit-update settings tox venv-init venv-remove venv-reset venv-version"
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
    echo "Saved completion file to $dir_path/$SCRIPT_NAME.completion"
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
# Required to generate apidoc with sphinx.
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

###########Dependency variables##################

# The python packages required to build the project.
# Some or all of these may also be requied in the
# requirements-dev.txt file
#
# BUILD_DEPENDENCIES="pip setuptools wheel build pip-tools"

# The location of the requirements.txt file.
#
# REQUIREMENTS_MAIN="./requirements.txt"

# The location of the requirements-dev.txt file
#
# REQUIREMENTS_DEV="./requirements-dev.txt"

#############Sphinx variables####################

# The Sphinx output directory
#
# DOC_BUILD_DIR="./docs/build"

# The sphinx documentation source directory
#
# DOC_SRC_DIR="./docs/source"

# The path to a web browser, used to view the generated documentation.
#
# BROWSER_PATH="/opt/google/chrome/chrome"

#############Distribution variables##############

# The path to the twine secrets .env file
#
# TWINE_SECRETS="./secrets/twine.env"

# The path to the twine test secrets .env file
# TWINE_TEST_SECRETS="./secrets/twine-test.env"

# The dist directory, where wheels and sdist are built.
#
# DIST_DIR="./dist"


EOF

    echo "Saved .env file to $dir_path/$ENV_NAME"
}

# This idea is heavily inspired by: https://github.com/adriancooney/Taskfile
# Runs the help function if no arguments given to script.
TIMEFORMAT=$'\nTask completed in %3lR'
time "${@:-help}"
################### No code below this line #####################
