# Dependent on svn_psh1.sh and git-completion.sh

__git_svn_ps1() {
    local s=
    local info=$(svn info 2> /dev/null)

    if [[ -n "$info" ]] ; then
        s=`__svn_ps1`
    else
        # if not a svn repo, then try git
        s=`__git_ps1`
    fi
    echo "$s"
}

