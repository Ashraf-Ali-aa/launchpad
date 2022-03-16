#!/usr/bin/env bash

###############################################################################
# ERROR: Let the user know if the script fails
###############################################################################

trap 'ret=$?; test $ret -ne 0 && printf "\n   \e[31m?\033[0m  Formation failed  \e[31m?\033[0m\n" >&2; exit $ret' EXIT

set -e

###############################################################################
# Check for required functions file
###############################################################################

if [ -e utils ]; then
	cd "$(dirname "${BASH_SOURCE[0]}")" && . "utils"
else
	printf "\n ??  ./utils not found  ???? First, you need to utils on your haters\n"
	exit 1
fi

###############################################################################
# CHECK: Bash version
###############################################################################

check_bash_version

###############################################################################
# Get in Formation!          http://patorjk.com/software/taag/ ( font: Script )
###############################################################################

printf "
#####################################################
#  Okay developers now let's get ready to ${bold}launch${normal}.   #
#####################################################
#  Safe to run multiple times on the same machine.  #
#  It ${green}installs${reset}, ${blue}upgrades${reset}, or ${yellow}skips${reset} packages based   #
#  on what is already installed on the machine.     #
#####################################################
${dim}$(get_os) $(get_os_version) ${normal} | ${dim}$BASH ${normal} | ${dim}$BASH_VERSION${reset}
"

###############################################################################
# CHECK: Internet
###############################################################################
chapter "Checking internet connection?"
check_internet_connection

###############################################################################
# PROMPT: Password
###############################################################################
chapter "Caching password?"
ask_for_sudo

###############################################################################
# PROMPT: SSH Key
###############################################################################
chapter 'Checking for SSH key?'
ssh_key_setup

###############################################################################
# INSTALL: Dependencies
###############################################################################
chapter "Installing Dependencies?"

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------
if ! [ -x "$(command -v brew)" ]; then
	step "Installing Homebrew?"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	export PATH="/usr/local/bin:$PATH"
	export PATH="/opt/homebrew/bin:$PATH"
	print_success "Homebrew installed!"
else
	print_success_muted "Homebrew already installed. Skipping."
fi

if brew list | grep -Fq brew-cask; then
	step "Uninstalling old Homebrew-Cask?"
	brew uninstall --force brew-cask
	print_success "Homebrew-Cask uninstalled!"
fi

# -----------------------------------------------------------------------------
# XCode
# -----------------------------------------------------------------------------
if xpath=$(xcode-select --print-path) && test -d "${xpath}" && test -x "${xpath}"; then
	print_success_muted "Xcode already installed. Skipping."
else
	step "Installing Xcode?"
	xcode-select --install
	print_success "Xcode installed!"
fi

if [ ! -d "$HOME/.bin/" ]; then
	mkdir "$HOME/.bin"
fi

# -----------------------------------------------------------------------------
# Rosetta
# -----------------------------------------------------------------------------
chapter "Checking Rosetta?"
checkRosetta()

# -----------------------------------------------------------------------------
# NVM
# -----------------------------------------------------------------------------
if ! [ -e $NVM_DIR ]; then
	step "Installing NVM?"
	# ensures that nvm
	touch ~/.bash_profile
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
	# This loads nvm for the terminal session
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
	print_success "NVM installed!"
	step "Installing latest Node?"
	nvm install --lts
	nvm use --lts
	nvm run node --version
	nodev=$(node -v)
	print_success "Using Node $nodev!"
else
	print_success_muted "NVM/Node already installed. Skipping."
fi


###############################################################################
# INSTALL: brews
###############################################################################
if [ -e "$cwd/sources/brews" ]; then
	chapter "Installing Homebrew formulae?"

	for brew in $(<"$cwd/sources/brews"); do
		install_brews "$brew"
	done
fi

###############################################################################
# UPDATE: Homebrew
###############################################################################
chapter "Updating Homebrew formulae?"

if ! brew doctor >/dev/null 2>&1; then
	brew tap --repair 2>&1
	brew update --preinstall 2>&1
fi

###############################################################################
# Install: Oh My Zsh
###############################################################################
chapter "Install Oh My Zsh"

if [ -d ~/.oh-my-zsh ]; then
	print_success_muted "Oh My Zsh already installed"
 else
 	print_success "Installing: Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

###############################################################################
# Setup: Ruby Manager - rbenv
###############################################################################
chapter "Setting up Ruby - rbenv and gems"

if ! which rbenv >/dev/null 2>&1; then
	LINE='eval "$(rbenv init -)"'

	echo "Adding $LINE to ZSH"
	grep -q "$LINE" ~/.zshrc || echo "$LINE" >>~/.zshrc

	source ~/.zshrc

fi

install_ruby_version

no_doc='gem: --no-document'

grep -q "$no_doc" ~/.gemrc || echo "$no_doc" >>~/.gemrc

if [ -e $cwd/sources/gems ]; then
	while read -r gem; do
		install_gem_packages "$gem"
	done <"$cwd/sources/gems"
fi

###############################################################################
# INSTALL: casks
###############################################################################
if [ -e "$cwd/sources/casks" ]; then
	chapter "Installing apps via Homebrew?"

	while read -r cask; do
		install_application_via_brew $cask
	done <"$cwd/sources/casks"
fi

###############################################################################
# INSTALL: Mac App Store Apps
###############################################################################
# chapter "Installing apps from App Store?"
# if [ -x mas ]; then
# 	print_warning "Please install mas-cli first: brew mas. Skipping."
# else
# 	if [ -e "$cwd/sources/mac-store" ]; then
# 		if mas_setup; then
# 			while read -r app; do
# 				KEY="${app%%::*}"
# 				VALUE="${app##*::}"

# 				install_application_via_app_store "$KEY" "$VALUE"
# 			done <$cwd/sources/mac-store
# 		else
# 			print_warning "Please signin to App Store first. Skipping."
# 		fi
# 	fi
# fi

###############################################################################
# CLEAN: Homebrew files
###############################################################################
chapter "Cleaning up Homebrew files?"
brew cleanup 2>/dev/null

###############################################################################
# INSTALL: npm packages
###############################################################################
if [ -e "$cwd/sources/npm" ]; then
	chapter "Installing npm packages?"

	for pkg in $(<"$cwd/sources/npm"); do
		KEY="${pkg%%::*}"
		VALUE="${pkg##*::}"
		install_npm_packages "$KEY" "$VALUE"
	done
fi

###############################################################################
# Configure: Apps
###############################################################################
chapter "Configure: Apps"

set_dock_options
set_hot_corners
set_finder_options
set_iterm_options

###############################################################################
# Configure: Alias
###############################################################################

if [ -e $cwd/sources/zsh_config ]; then
	chapter "Configure: ZSH Alias"

	while read -r option; do
		if grep -q "$option" ~/.zshrc; then
			print_success_muted "Skipping: $option"
		else
			print_success "Adding: $option"
			echo "$option" >>~/.zshrc
		fi
	done <"$cwd/sources/zsh_config"
fi

if [ -e $cwd/sources/git_config ]; then
	chapter "Configure: Git Alias"

	while read -r option; do
		grep -q "$option" ~/.gitconfig || echo "$option" >>~/.gitconfig
	done <"$cwd/sources/git_config"
	print_success_muted "Added to .gitconfig"
fi

###############################################################################
# Finish Script
###############################################################################
we_have_lift_off
