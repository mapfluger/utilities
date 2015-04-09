alias ll='ls -lGphFa'
alias ls='ls -GFhAp'
alias markSource='source ~/Projects/vistacore/utilities/shellsettings/test.sh'
alias advGrep='sh ~/Projects/vistacore/utilities/shellsettings/grep.sh'
alias ..="cd .."
alias cd..="cd .."
alias c="clear"
alias ve='cd $ve'
alias cdo='cd -'
#alias grep='grep --color=auto'
export GREP_OPTIONS='--color=auto'
export CLICOLOR=1
source ~/Projects/vistacore/utilities/shellsettings/bookmarks.sh
source ~/Projects/vistacore/utilities/shellsettings/git-prompt.sh
source ~/Projects/vistacore/utilities/shellsettings/utilities.sh
#PS1='\[\e[0;32m\]\u\[\e[m\] \[\e[1;34m\]\w\[\e[m\] \[\e[1;32m\]\$\[\e[m\] \[\e[1;37m\]'

set_prompt () {
    Last_Command=$? # Must come first!
    Blue='\[\e[01;34m\]'
    White='\[\e[01;37m\]'
    Red='\[\e[01;31m\]'
    Green='\[\e[01;32m\]'
    Magenta='\[\e[35m\]'
    Reset='\[\e[00m\]'
    FancyX='\342\234\227'
    Checkmark='\342\234\223'

    # Add a bright white exit status for the last command
    #PS1="$White\$? "
    # If it was successful, print a green check mark. Otherwise, print
    # a red X.
    if [[ $Last_Command == 0 ]]; then
        PS1="$Green$Checkmark"
    else
        PS1="$Red$FancyX\$?"
    fi
    # If root, just print the host in red. Otherwise, print the current user
    # and host in green.
    if [[ $EUID == 0 ]]; then
        PS1+="$Red\\h:"
    else
        PS1+="$Green\\u:"
    fi
    # Print the working directory and prompt marker in blue, and reset
    # the text color to the default.
    PS1+="$Magenta$ITERM_PROFILE:$Blue\W$(__git_ps1)\\\$$Reset "
    #PS1+='\u \W$(__git_ps1)\$ '
}
PROMPT_COMMAND='set_prompt'
