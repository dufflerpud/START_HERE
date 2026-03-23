#!/bin/sh
#
#indx#	START_HERE.sh - A script to grab the Install_and_Build script and run it
#@HDR@	$Id$
#@HDR@
#@HDR@	Copyright (c) 2026 Christopher Caldwell (Christopher.M.Caldwell0@gmail.com)
#@HDR@
#@HDR@	Permission is hereby granted, free of charge, to any person
#@HDR@	obtaining a copy of this software and associated documentation
#@HDR@	files (the "Software"), to deal in the Software without
#@HDR@	restriction, including without limitation the rights to use,
#@HDR@	copy, modify, merge, publish, distribute, sublicense, and/or
#@HDR@	sell copies of the Software, and to permit persons to whom
#@HDR@	the Software is furnished to do so, subject to the following
#@HDR@	conditions:
#@HDR@	
#@HDR@	The above copyright notice and this permission notice shall be
#@HDR@	included in all copies or substantial portions of the Software.
#@HDR@	
#@HDR@	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
#@HDR@	KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
#@HDR@	WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
#@HDR@	AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#@HDR@	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#@HDR@	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#@HDR@	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#@HDR@	OTHER DEALINGS IN THE SOFTWARE.
#
#hist#	2026-02-22 - Christopher.M.Caldwell0@gmail.com - Created
########################################################################
#doc#	START_HERE.sh - A script to grab the Install_and_Build script and run it.
#doc#	Don't over think this.  You WILL PROBABLY decide to just get the
#doc#	Install_and_Build script by hand and run it yourself.  This is
#doc#	as complex as it is only to help debug the installer.  By the time
#doc#	you are working with it, we hope the installer already works.
#doc#	So just run it and ignore this.
#doc#
#doc#	Installs script only for debugging purposes.
#doc#
#doc#	Installs git because the majority of time, we get the installer
#doc#	right off github.com.  Installer will also make sure git gets installed
#doc#	because sometimes it gets here otherwise.  Assume as little as possible.
########################################################################

INSTALL_SCRIPT=Install_and_Build.sh
#DEFAULT_URL=https://github.com/dufflerpud/START_HERE.git
#DEFAULT_URL=https://raw.githubusercontent.com/dufflerpud/START_HERE/refs/heads/main/$INSTALL_SCRIPT
DEFAULT_URL=chris@10.1.0.20:/usr/local/projects/START_HERE/$INSTALL_SCRIPT

TMP=/tmp/`basename $0 .sh`

#########################################################################
#	Show what you're going to do and then do it.			#
#########################################################################
echodo()
    {
    echo "+ $*"
    "$@"
    }

#########################################################################
#	Show what you're going to do and then do it.			#
#########################################################################
ecsudo()
    {
    echo "! $*"
    if command -v sudo >/dev/null ; then
        sudo "$@"
    else
       "$@" 
    fi
    }

#########################################################################
#	Figure out what the installer is.				#
#########################################################################
determine_os()
    {
    for try_installer in dnf yum apt-get pacman freebsd-version pkg zypper pkgman; do
        if command -v $try_installer >/dev/null ; then
	    INSTALLER=$try_installer
	    break
	fi
    done
    [ -n "$INSTALLER" ] || fatal "Cannot find an installer."
    }

#########################################################################
#	Figure out how to install something then install it.		#
#########################################################################
osinstall()
    {
    case "$INSTALLER" in
        dnf)			ecsudo dnf -yq install $*			;;
	yum)			ecsudo yum -yq install $*			;;
	apt-get)		ecsudo apt-get install -qqy $*			;;
	pacman)			ecsudo pacman -S --noconfirm --noprogressbar $*	;;
	zypper)			ecsudo zypper install -y $*			;;
	pkgman)			ecsudo pkgman install -y $*			;;
	freebsd-version)	ecsudo pkg install -y $*			;;
	pkg)			ecsudo pkg install $*				;;
    esac
    }

#########################################################################
#	Main								#
#########################################################################

umask 002
determine_os

command -v script >/dev/null || osinstall script

#Overridable with the environment
URL=${START_HERE_URL:-"$DEFAULT_URL"}

rm -rf $TMP.*
case "$URL" in
    *.git)	command -v git >/dev/null || osinstall git
		mkdir -p $TMP.sandbox
		echodo git -C $TMP.sandbox clone "$URL"
		echodo cp $TMP.sandbox/START_HERE/$INSTALL_SCRIPT $INSTALL_SCRIPT
		;;
    http*)	command -v curl >/dev/null || osinstall curl
		echodo curl -o $INSTALL_SCRIPT "$URL"
    		;;
    *)		command -v scp >/dev/null || osinstall openssh
		echodo scp "$URL" $INSTALL_SCRIPT
    		;;
esac

echodo chmod 755 $INSTALL_SCRIPT

if command -v script >/dev/null ; then
    if command -v freebsd-version >/dev/null ; then
	script $TMP.raw ./$INSTALL_SCRIPT
    else
	script -c "sh -x $INSTALL_SCRIPT $*" $TMP.raw
    fi
    /usr/local/bin/descape < $TMP.raw > $TMP.log
else
    sh -x $INSTALL_SCRIPT
fi
