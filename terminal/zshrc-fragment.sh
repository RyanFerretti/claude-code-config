# >>> claude-code-config >>>
# Appended by bootstrap.sh. Edit in the repo (terminal/zshrc-fragment.sh), not
# here — bootstrap replaces everything between these markers on each run.
#
# Deliberately contains NO secrets and no per-client config. Machine-specific
# API keys belong in the keychain or a gitignored file sourced after this block.

# Homebrew (Apple Silicon)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Prompt. starship.toml is installed alongside this by bootstrap; without this
# init line the config is present but unused.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# Node version manager
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd)"

# bun
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# uv and other user-level installs. uv drives the Claude Code status line, so if
# it is missing from PATH the status line renders as nothing at all.
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

alias python=python3
alias pip=pip3
# <<< claude-code-config <<<
