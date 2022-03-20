h#!/usr/bin/env bash
trap 'ret=$?; test $ret -ne 0 && printf "\n   \e[31m?\033[0m  Formation failed  \e[31m?\033[0m\n" >&2; exit $ret' EXIT

set -e

ask() {
    # https://djm.me/ask
    local prompt default reply

    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "  [?] $1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read -r reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
        Y* | y*) return 0 ;;
        N* | n*) return 1 ;;
        esac

    done
}


cli_is_installed() {
    # set to 1 initially
    local return_status=1
    # set to 0 if not found
    type "$1" >/dev/null 2>&1 || { local return_status=0; }
    # return value
    echo "$return_status"
}

copy_key_github() {
    echo "Public key copied, Paste into Github"
    [[ -f "$pub" ]] && cat "$pub" | pbcopy
    open 'https://github.com/account/ssh'
    read -r -p "   ✦  Press enter to continue"
    echo "SSH key"
    return
}

github_key_check() {
    if ask "SSH key found. Enter it in Github?" Y; then
        copy_key_github
    else
        echo "SSH key"
    fi
}

create_ssh_key() {
    if ask "No SSH key found. Create one?" Y; then
        ssh-keygen -t rsa
        github_key_check
    else
        return 0
    fi
}

ssh_key_setup() {
    local pub=$HOME/.ssh/id_rsa.pub

    if ! [[ -f $pub ]]; then
        create_ssh_key
    else
        github_key_check
    fi
}

ask_for_sudo() {

    # Ask for the administrator password upfront.

    sudo -v &>/dev/null

    # Update existing `sudo` time stamp
    # until this script has finished.
    #
    # https://gist.github.com/cowboy/3118588

    # Keep-alive: update existing `sudo` time stamp until script has finished
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &

    echo "Password cached"
}

###############################################################################
# PROMPT: Password
###############################################################################
echo "Caching password?"
ask_for_sudo

###############################################################################
# PROMPT: SSH Key
###############################################################################
echo 'Checking for SSH key?'
ssh_key_setup

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------
if ! [ -x "$(command -v brew)" ]; then
	step "Installing Homebrew?"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	export PATH="/usr/local/bin:$PATH"
	export PATH="/opt/homebrew/bin:$PATH"
	echo "Homebrew installed!"
else
	echo "Homebrew already installed. Skipping."
fi

if brew list | grep -Fq brew-cask; then
	step "Uninstalling old Homebrew-Cask?"
	brew uninstall --force brew-cask
	echo "Homebrew-Cask uninstalled!"
fi

# -----------------------------------------------------------------------------
# XCode
# -----------------------------------------------------------------------------
if xpath=$(xcode-select --print-path) && test -d "${xpath}" && test -x "${xpath}"; then
	echo "Xcode already installed. Skipping."
else
	step "Installing Xcode?"
	xcode-select --install
	echo "Xcode installed!"
fi

if [ ! -d "$HOME/.bin/" ]; then
	mkdir "$HOME/.bin"
fi

if [ ! -d "$HOME/launchpad" ]; then
	echo "Downloading Launchpad Tool"
	(cd $HOME; git clone git@github.com:Ashraf-Ali-aa/launchpad.git)
fi

echo "Running Launchpad Tool"
sh "$HOME/launchpad/launchpad.sh"
