#
#  $Id$
#

HOME=`pwd`

# [ -z "$VIRTDEV_HOME" ] || exit
VIRTDEV_HOME=$HOME;
export VIRTDEV_HOME

PATH=".:$HOME/bin:/usr/local/bin:$PATH"
CDPATH=.:$HOME/libsrc:$HOME/binsrc:$HOME:$HOME/binsrc/samples:$HOME/binsrc/tests
CVSIGNORE='.AppleDouble *.exe *.lis *.obj *.olb *;* *.makeout'
LD_LIBRARY_PATH=$HOME/lib:DEFAULT

#You may use this one...
PS1='VIRTMAIN:\w\$ '

#...or if you mark different versions by YYMMDD date, try this...
#pwd | grep '^\([^0-9]*\)\([0-9][0-9]*\)\(.*\)$' > /dev/null && PS1=`pwd | sed 's/^\([^0-9]*\)\([0-9][0-9]*\)\(.*\)$/\2:WOW:\\\w\\\$ /'` || PS1='VIRTUOSO:\w\$ '

#...or you may try this for generic case...
#PS1=`pwd | sed 's/^\(.*\)home\(_*\)//g' | sed 's/virt/VIRT/g' | sed 's/dev/DEV/g' | sed 's/uoso/UOSO/g' | sed 's/cvs/CVS/g' | sed 's/\([a-z/]\)//g'`
#PS1="$PS1:\\w\\$ "

if [ -f "$HOME/CVS/Tag" ]
then
  PS1=`cat "$HOME/CVS/Tag" | cut -b 2-`'@\h:\w\$ '
else
  PS1='VIRTMAIN@\h:\w\$ '
fi

#If coming in from an xterm-debian, resolve down to ordinary "xterm"
env | grep 'TERM=xterm' && TERM=xterm

CVS_RSH=ssh
export MAINTAINER CVS_RSH TERM

#These two sets are to make visible in MC that we're in Virtdev
#MC_COLOR_TABLE="normal=,red:marked=,red:executable=,red:directory=,red:link=,red:device=,red:special=blue,red"
MC_COLOR_TABLE="normal=cyan,"

export MC_COLOR_TABLE

PORT=1111
if [ -f /home/staff/virtuoso_ports ] ; then
  {
    cat /home/staff/virtuoso_ports | grep $HOME: | sed 's/^\(.*\):\([0-9]\+\)$/\2/g' > .port
    PORT=`cat .port`
    rm .port
    [ -z "$PORT" ] && PORT=1111
    echo "PORT is set to $PORT"
  }
fi
export PORT

export PATH CDPATH CVSROOT CVSIGNORE UDBCINI LD_LIBRARY_PATH HOME ODBCINI JDK1 JDK2

#MONO_PATH=$HOME/binsrc/tests/biftest/tests
#export MONO_PATH

[ -s .profile.sysdep ] && . .profile.sysdep

umask 022
