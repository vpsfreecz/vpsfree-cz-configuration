# prompt -{
# colors -{
RED='\[\033[01;31m\]'
GREEN='\[\033[01;32m\]'
YELLOW='\[\033[01;33m\]'
BLUE='\[\033[01;34m\]'
PURPLE='\[\033[01;35m\]'
CYAN='\[\033[01;36m\]'
WHITE='\[\033[01;37m\]'
NIL='\[\033[00m\]'
# }-
# hostname style
FULL='\H'
SHORT='\h'
#   UC: username color
#   LC: location/cwd color
#   HC: hostname color
#   HD: hostname display (\h vs \H)
# Defaults:
UC=$GREEN
LC=$BLUE
HC=$GREEN
HD=$SHORT

HOST=`hostname | cut -d '.' -f 1`
DOMAIN=`hostname | cut -d '.' -f 2-`

if [ $HOST != "grampi" ]; then
  HC=$RED
fi

function set_prompt {
  RET=$?

  # Shorten path, if shortened prepend ... -{
  # how many characters of the $PWD should be kept
  local pwd_length=23
  nPWD="$PWD"
  if [[ "$PWD" =~ "$HOME" ]]; then
    if [[ "$PWD" = "$HOME" ]]; then
        nPWD="~"
      else
        nPWD="~`echo -n ${PWD#*$HOME}`"
      fi
  fi
  if [ $(echo -n $nPWD | wc -c | tr -d " ") -gt $pwd_length ]; then
    newPWD="...$(echo -n $nPWD | sed -e "s/.*\(.\{$pwd_length\}\)/\1/")"
  else
    newPWD="$(echo -n $nPWD)"
  fi
  # }-

  # Git branch / dirtiness -{
  if git update-index -q --refresh 2>/dev/null; git diff-index --quiet --cached HEAD --ignore-submodules -- 2>/dev/null && git diff-files --quiet --ignore-submodules 2>/dev/null
    then dirty=""
  else
    dirty="${RED}*${NIL}"
  fi
  _branch=$(git symbolic-ref HEAD 2>/dev/null)
  _branch=${_branch#refs/heads/}
  branch=""
  if [[ -n $_branch ]]; then
    branch="${NIL}[${WHITE}${_branch}${dirty}${NIL}]"
  fi
  # }-

  venv="${NIL}(${CYAN}$NIXOPS_DEPLOYMENT${NIL})"

  host="${HC}@${HD}${NIL}"

  if [ "$USER" = "root" ]; then
    user="${RED}\u${NIL}"
    end_char="#"
  else
    user="${UC}\u${NIL}"
    end_char="$"
  fi

  path="${LC}${newPWD}${NIL}"

  if [ $RET = 0 ]; then
    end="${LC}${end_char} ${NIL}"
  else
    end="${RED}${end_char} ${NIL}"
  fi

  # prompt styles
  case $PROMPT_STYLE in
    default )
      export PS1="${venv}${branch}${user}${at}${host} ${path} ${end}" ;;
    long )
      export PS1="\n${venv}${branch}${user}${at}${host} ${PWD} \n${end}" ;;
  esac

  PS1="\[\033[G\]$PS1"
}

export PROMPT_COMMAND=set_prompt


function prompt_long() {
  export PROMPT_STYLE=long
}
function prompt_default() {
  export PROMPT_STYLE=default
}

prompt_long

# }-
