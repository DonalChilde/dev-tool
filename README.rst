================
dev-tool.sh
================

A bash script to automate some python dev tasks.

Installation
------------

Use curl or wget to download the script.

.. code-block:: bash

    # Download to the current directory.
    curl -O https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool.sh
    # or
    wget https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool.sh

    # Download to a subdirectory
    curl --create-dirs -O --output-dir ./scripts https://raw.githubusercontent.com/DonalChilde/dev-tool/main/scripts/dev-tool.sh

    # Then make executable
    chmod u+x ./dev-tool.sh

    # Run script for a list of commands
    ./dev-tools.sh

    # Install bash completion if desired
    ./dev-tool.sh completions .

    # Move the generated completion script to a completions directory,
    mv ./dev-tool.completion ~/.bash-completions/

    # and add
    source ~/.bash-completions/dev-tool.completion
    # to ~/.bashrc

    # Generate an .env config file to the script directory.
    ./dev-tool.sh generate-env .

    # The script will first look for the .env file in the pwd,
    # then the script directory.



Usage
-----