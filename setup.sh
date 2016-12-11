#!/bin/sh

# Macbook setup script
# Inspired by https://github.com/18F/laptop

set -euo pipefail

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

fancy_echo() {
  # shellcheck disable=SC2039
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

append_to_file() {
  # shellcheck disable=SC2039
  local file="$1"
  # shellcheck disable=SC2039
  local text="$2"

  if ! grep -qs "^$text$" "$file"; then
    printf "\n%s\n" "$text" >> "$file"
  fi
}

brew_is_installed() {
  brew list -1 | grep -Fqx "$1"
}

gem_install_or_update() {
  if gem list "$1" | grep "^$1 ("; then
    fancy_echo "Updating %s ..." "$1"
    gem update "$@"
  else
    fancy_echo "Installing %s ..." "$1"
    gem install "$@"
  fi
}

app_is_installed() {
  # shellcheck disable=SC2039
  local app_name
  app_name=$(echo "$1" | cut -d'-' -f1)
  find /Applications -iname "$app_name*" -maxdepth 1 | egrep '.*' > /dev/null
}

# install homebrew
if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby
else
  fancy_echo "Homebrew already installed. Skipping ..."
fi

# Remove brew-cask since it is now installed as part of brew tap caskroom/cask.
# See https://github.com/caskroom/homebrew-cask/releases/tag/v0.60.0
if brew_is_installed 'brew-cask'; then
  brew uninstall --force 'brew-cask'
  brew untap caskroom/versions
fi

# update brew index
fancy_echo "Updating Homebrew formulas ..."
brew update

# verify homebrew installation
fancy_echo "Verifying the Homebrew installation..."
if brew doctor; then
  fancy_echo "Your Homebrew installation is good to go."
else
  fancy_echo "Your Homebrew installation reported some errors or warnings."
  echo "If the warnings are related to Python, you can ignore them."
  echo "Otherwise, review the Homebrew messages to see if any action is needed."
fi

# install nodejs
fancy_echo 'Checking Node.js installation.'

if ! brew_is_installed "node"; then
  brew bundle --file=- <<EOF
  brew 'node'
EOF
fi

fancy_echo '...Finished Node.js installation.'

# install python3
fancy_echo 'Checking Python3 installation.'

if ! brew_is_installed "python3"; then
  brew bundle --file=- <<EOF
  brew 'python3'
EOF
fi

fancy_echo '...Finished Python3 installation.'

# install ruby
fancy_echo 'Checking Ruby installation.'

append_to_file "$HOME/.gemrc" 'gem: --no-document'

fancy_echo 'Updating Rubygems...'
gem update --system

gem_install_or_update 'bundler'

fancy_echo "Configuring Bundler ..."
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

fancy_echo '...Finished Ruby installation.'

# install brew packages from Brewfile
fancy_echo "Installing formulas and casks from the Brewfile ..."
brew bundle

if app_is_installed 'GitHub'; then
  fancy_echo "It looks like you've already configured your GitHub SSH keys."
  fancy_echo "If not, you can do it by signing in to the GitHub app on your Mac."
elif [ ! -f "$HOME/.ssh/github_rsa.pub" ]; then
  open ~/Applications/GitHub\ Desktop.app
fi

fancy_echo 'All done!'
