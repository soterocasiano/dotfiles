export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH="$PATH:/Users/w526201/scripts"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
source $ZSH/oh-my-zsh.sh

daily() {
    local result=$(obsidian-cli daily)
}

obs() {
    local result=$(obsidian-cli open Tasks)
}

bindkey -e

cf() {
    codefresh "$@"
}

g() {
    if [ "$1" = "c" ]; then
        git commit -s -m "${*:2}"
    fi
    if [ "$1" = "a" ]; then
        git add --all
    fi
    if [ "$1" = "p" ]; then
        git push
    fi
    if [ "$1" = "br" ]; then
        git branch "${@:2}"
    fi
    if [ "$1" = "co" ]; then
        git checkout "${@:2}"
    fi
    if [ "$1" = "ci" ]; then
        git commit "${@:2}"
    fi
    if [ "$1" = "st" ]; then
        git status "${@:2}"
    fi
    if [ "$1" = "last" ]; then
        git log -1 HEAD
    fi
    if [ "$1" = "root" ]; then
        git rev-parse --show-toplevel
    fi
    if [ "$1" = "last-sha" ]; then
        git log -1 --pretty=format:"%H"
    fi
}

release() {
    source /Users/w526201/personal/sdd/config-release/.venv/bin/activate
    python /Users/w526201/personal/sdd/config-release/src/main.py
}

k() {
    if [ -z "$1" ]; then
        kubectl "$@"
    fi
}

kx() {
    if [ -n "$1" ]; then
        kubectl config use-context "$1"
    else
        kctx
    fi
}

alias ack='echo "Use ag"'
alias awsprofiles="grep '^\[profile' ~/.aws/config | cut -d' ' -f2 | cut -d']' -f1 | sort"
alias ccat='pygmentize -g'
alias c='codefresh'
alias cx='codefresh auth use-context'
alias kl='kubectl logs'
alias kgp='kubectl get pods'
alias kx=kubectx
alias mc='SHELL=/opt/homebrew/bin/bash mc'
alias px='pulumi login'
alias unsetaws='unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN'
alias wc=gwc
source /opt/homebrew/opt/fzf/shell/completion.zsh
source /opt/homebrew/opt/fzf/shell/key-bindings.zsh

export CONFLUENCE_EMAIL="sotero.casiano@wawa.com"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

export TIER_CONFIGS_DIR="/Users/w526201/devel/iac-mobile-tier-configurations"
export SUPPORT_DIR="/Users/w526201/devel/iac-mobile-mobapp-support"
export NODE_NO_WARNINGS=1

export ARTIFACTORY_USER="sotero.casiano@wawa.com"
