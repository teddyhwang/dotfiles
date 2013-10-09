# Dependent on svn_psh1.sh and git-completion.sh

__git_svn_hg_ps1() {
    local s=
    local svninfo=`svn info 2> /dev/null`
    local hg=`hg prompt " ({branch}:{rev})" 2> /dev/null`

    if [[ -n "$svninfo" ]] ; then
        s=`__svn_ps1`
    elif [[ -n "$hg" ]] ; then
        s=`__hg_ps1`
    else
        # if not a svn repo, then try git
        s=`__git_ps1`
    fi
    echo "$s"
}

