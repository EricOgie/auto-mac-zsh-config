#! /bin/bash
#
# This script should be run using curl:
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/EricOgie/auto-mac-zsh-config/main/setup.sh)"

# or using wget:
# sh -c "$(wget -qO- https://raw.githubusercontent.com/EricOgie/auto-mac-zsh-config/main/setup.sh)"

# or using fetch:
# sh -c "$(fetch -o - https://raw.githubusercontent.com/EricOgie/auto-mac-zsh-config/main/setup.sh)"

# For a more personalised usage, you can download the setup.sh script, tweak  and run afterward.
#
set -e

# Ensure required variables exist.
# Establish a min ruby version of 3.1.0
MIN_RUBY_VERSION="3.1.0"

# Get current Ruby version.
# A simple ruby -v | awk '{print $2}' can output x.x.xpx instead of x.x.x
# Remove any unwanted [a-zA-Z] from the version output using sed
CURRENT_RUBY_VERSION=$(ruby -v | awk '{print $2}' | sed 's/[a-zA-Z].*//')

# Compute the lower version between CURRENT_RUBY_VERSION and MIN_RUBY_VERSION
LOWER_VERSION=$(printf '%s\n%s\n' "$CURRENT_RUBY_VERSION" "$MIN_RUBY_VERSION" | sort -V | head -n 1)

DEFAULT_ZSHRC="$HOME/.zshrc"

# ~/.zshrc file backup location
BACKUP_DIR="$HOME/AMZC-backups"
BACKUP_ZSHRC="$BACKUP_DIR/.zshrc.bak_$(date +%Y%m%d_%H%M%S)"

# Login User and User home
USER=${USER:-$(id -u -n)}
HOME="${HOME:-$(eval echo ~$USER)}"
PLUGINS_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/


command_exists(){
    # Check if a command is available on the system.
    #
    # Arguments:
    #   $@ - Command(s) to check.
    #
    # Returns:
    #   0 if the command exists and is executable.
    #   1 if the command does not exist or is not executable.
    command -v "$@" > /dev/null 2>&1 
}


handle_error() {
    # Print the error message using formatted output
    printf 'Error: %s\n' "$1" >&2
    exit 1
}


execute_command() {
    local cmd="$*"
    local output

    # Execute the command and capture any output or error message
    output=$($cmd 2>&1) || handle_error "Command failed: $cmd : Msg: $output"
    echo "$output"
}

can_sudo() {
    # This function checks if the user can use the sudo command.
    # It performs two checks:
    # 1. Checks if sudo is installed.
    # 2. Attempts to refresh the sudo timestamp to verify if the user has valid sudo permissions.
    #    - If there is an active sudo session, this will succeed without prompting for a password.
    #    - If there is no active session or the user needs to authenticate, this will prompt for a password.

    # Check if sudo is installed
    command_exists sudo || return 1

    # Attempt to refresh the sudo timestamp to validate sudo permissions
    # Redirect output to /dev/null to avoid displaying any prompts or errors
    sudo -v >/dev/null 2>&1
}

print_section_header() {
    echo
    echo "***********************************************"
    echo "${2:-Installing} $1"
    echo "***********************************************"
    echo
}

print_finish_feedback () {
    echo 
    echo "****** Successfully installed $1 ******"
    echo
}


install_prerequisites() {
    print_section_header "Preliminary Checks and Configurations" "Running"
    # Check if Homebrew is installed - Install if not
    if ! command_exists brew; then
        echo "Homebrew not found. Installing Homebrew..."
        execute_command /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Run update
        execute_command brew update

        print_finish_feedback  Homebrew

    fi

    # Check if zsh is installed - Install if not
    if ! command_exists zsh; then
        echo "Zsh shell not found.  Installing..."
        execute_command brew install zsh
        print_finish_feedback  "zsh shell"
    fi

    # Setup Zsh as default shell if not set
    if [[ "$SHELL" != *"zsh" ]]; then
        echo "Default login shell is not zsh. Configuring zsh as default shell for $USER..."
        execute_command chsh -s $(which zsh)
        echo "zsh shell now default login shell for $USER"
        echo
    fi

    # Backup ~/.zshrc file for rollback purposes
    if [ -f "$HOME/.zshrc" ]; then
        echo "Saving the default $HOME/.zshrc file content to $BACKUP_ZSHRC"
        mkdir -p $BACKUP_DIR && cp $DEFAULT_ZSHRC $BACKUP_ZSHRC
        echo "$HOME/.zshrc Backed up at $BACKUP_ZSHRC."
        echo
    else
        echo "No existing .zshrc file found - No backup needed"
    fi

}


install_oh_my_zsh() {
     # Install Oh-my-zsh
    print_section_header "oh-my-zsh"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then 
        echo "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_finish_feedback  oh-my-zsh
    else
        echo "Oh-My-Zsh is already installed."
    fi
}


install_themes_and_fonts() {

    print_section_header "Themes and Fonts"

    # Install Powerlevel10k theme
    if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
        echo "Installing Powerlevel10k theme..."
        execute_command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
        
        # Set the theme to Powerlevel10k in ~/.zshrc file
        sed -i '' 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

        print_finish_feedback  "Powerlevel10k theme"

    else
        echo "Powerlevel10k theme already installed."
        echo "Moving on to other installations..."
        echo
    fi

    # Install and configure Nerd Fonts
    if [ ! -f "$HOME/Library/Fonts/HackNerdFont-Regular.ttf" ]; then
        echo "Installing Hack Nerd Font..."
        execute_command env HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask font-hack-nerd-font
        print_finish_feedback  "Hack Nerd Font"
    else
        echo "Hack Nerd Font already installed"
    fi

    # Update iTerm2 preferences to use Hack Nerd Font
    echo "Configuring Iterm2 to use Hack Nerd Font for Non Ascii Font"
    # Set Non-ASCII Font
    defaults write com.googlecode.iterm2 "Non Ascii Font" -string "HackNF-Regular 12"
    # Set Normal Font
    defaults write com.googlecode.iterm2 "Normal Font" -string "MesloLGS-NF-Regular 13" 
    # Ensure Non-ASCII Font usage is enabled
    defaults write com.googlecode.iterm2 "Use Non-ASCII Font" -bool true
}


install_plugins() {
    print_section_header "Plugins"
    # Install zsh plugins
    # - Install zsh-syntax-highlighting
    if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
        echo "Installing zsh-syntax-highlighting..."
        execute_command git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        print_finish_feedback  "zsh-syntax-highlighting"
    else
        echo "zsh-syntax-highlighting is already installed"
        echo "Moving on to other installations..."
        echo
    fi
    
    if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
        # - Install zsh-autosuggestions
        echo
        echo "Installing zsh-autosuggestions..."
        execute_command git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        print_finish_feedback  "zsh-autosuggestions"
    else
        echo "zsh-autosuggestions is already installed"
        echo
    fi

    # Add plugins to .zshrc
    sed -i '' 's/^plugins=(.*)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc

}

install_colorls() {
    print_section_header "colorls"
    if ! command_exists colorls; then

        # Check if CURRENT_RUBY_VERSION meets the min requirment of 3.1.0. If not, Install a compartible version using rbenv.
        # Note: CURRENT_RUBY_VERSION here is system installed ruby version.
        if [[ "$LOWER_VERSION" != "$MIN_RUBY_VERSION" ]]; then

            echo "Your current Ruby version, $CURRENT_RUBY_VERSION is below the minimum required version, $MIN_RUBY_VERSION."
            echo "Installing a compartible Ruby version..."
            echo 

            if ! command_exists rbenv ; then
                execute_command brew install rbenv
                execute_command brew install ruby-build
                print_finish_feedback  "rbenv"
            fi


            if ! rbenv versions | grep -q "3.1.0"; then
                echo "Installing ruby 3.1.0 using rbenv"
                echo
                execute_command rbenv install 3.1.0
                execute_command rbenv global 3.1.0
                execute_command rbenv rehash

                print_finish_feedback  "ruby@v3.1.0"
            fi

        fi

        # Ensure rbenv initialized in each terminal session 
        echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc
        source ~/.zshrc

        # If rbenv is used to install a compartible ruby (as seen above), we may have a situation where two ruby versions exist in parallel -
        # System installed ruby and rbenv managed ruby. 
        # When Ruby gems are installed, bash will naturally default to the system installed Ruby (whose version may be < min req) 
        # To ensure rbenv Ruby is use for gem installations, we init rbenv in the running bash session
        echo "Initialized rbenv in current bash session..."
        if command_exists rbenv; then
            eval "$(rbenv init - bash)"
        fi

        # Install colorls
        execute_command sudo gem install colorls
        print_finish_feedback  "colorls"
   
    fi

    
    if ! (grep -q "alias ls=colorls" ~/.zshrc || grep -q "alias ls='colorls'" ~/.zshrc); then
        # Prompt user to add alias ls=colorls
        read -p "Would you like to set up 'ls' alias to use colorls? (y/n): " setup_alias

        # Check user's response and respond accordingly
         if [[ $setup_alias == "y" || $setup_alias == "Y" ]]; then
            echo "Adding alias 'ls=colorls' to ~/.zshrc..."
            echo "alias ls=colorls" >> ~/.zshrc
         else
            echo "Skipping alias setup..."
         fi
    fi

}


main() {

    can_sudo

    install_prerequisites

    install_oh_my_zsh

    install_themes_and_fonts

    install_plugins

    install_colorls
    
    echo "Installation complete - You are all set!"
    echo 
    echo "Restart your terminal and follow configuration wizard to customize your terminal looks"
  
}


main "$@"
