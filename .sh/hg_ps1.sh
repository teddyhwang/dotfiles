__hg_ps1() {
    local hg=`hg prompt "{branch}:{rev}{status}" 2> /dev/null`
    local st=${hg: -1}
    local re='^[0-9]+$'

    if [[ $st =~ $re ]]; then
        echo -e ' ('$hg')'
    else
        hg=${hg%?}
        echo -e ' ('$hg'\033[31m'$st'\033[32m)'
    fi
}
