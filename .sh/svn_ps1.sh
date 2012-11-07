__svn_ps1() {
    local r=`__svn_rev`
    local b=`__svn_branch`
    local s=" ($b:$r)"

    echo -n "$s"
}

# Outputs the current trunk, branch, or tag
__svn_branch() {
    local url=`svn info | awk '/URL:/ {print $2}'`

    if [[ $url =~ trunk ]]; then
        echo trunk
    elif [[ $url =~ /branches/ ]]; then
        echo $url | sed -e 's#^.*/\(branches/.*\)/.*$#\1#'
    elif [[ $url =~ /tags/ ]]; then
        echo $url | sed -e 's#^.*/\(tags/.*\)/.*$#\1#'
    fi
}

# Outputs the current revision
__svn_rev() {
    local r=`svn info | awk '/Revision:/ {print $2}'`
    local st=`svn status | grep '^\s*[?ACDMR?!]'`
    local flag

    if [[ -n "$st" ]] ; then
        flag=*
    fi

    echo -e $r'\033[31m'$flag'\033[32m'
}
