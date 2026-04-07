#!/bin/sh
set -x
#
#indx#	Install_and_Build.sh - A script to download and install all of the dufflerpud projects
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
#doc#	Install_and_Build.sh - A script to download and install all of the dufflerpud projects
########################################################################

PROG=`basename $0 .sh`
USER=`id -un`
GROUP=`id -gn`
BE_CLEAN=false
DEVELOPER=false
DISABLE_SELINUX=true
REBOOT_REASON=
SYSTEM_USER=0
SYSTEM_GROUP=0
SYSTEM_DIRECTORY_ATTRIBUTES="-D -d -m 0755 -o $SYSTEM_USER -g $SYSTEM_GROUP"
SYSTEM_EXECUTABLE_ATTRIBUTES="-D -m 0755 -o $SYSTEM_USER -g $SYSTEM_GROUP"
SYSTEM_READABLE_ATTRIBUTES="-D -m 0644 -o $SYSTEM_USER -g $SYSTEM_GROUP"
TMP=/tmp/$PROG

#########################################################################
#	Returns if $OS_LIKE is the specified argument.			#
#########################################################################
#doc# ### os_of()
#doc# Return true if the current OS is any of the arguments
os_of()
    {
    echo " $* " | grep -iq " $OS_LIKE "
    }

#########################################################################
#	Echo command and then do it.					#
#########################################################################
#doc# ### echodo()
#doc# Print a command and execute it
echodo()
    {
    echo "+ $@" >&2
    "$@"
    }

#########################################################################
#	Returns true if argument is in our path.			#
#########################################################################
#doc# ### in_path()
#doc# Return true if argument is executable in path.
in_path()
    {
    command -v "$1" >/dev/null	# Exit status becomes subroutine status
    }

#########################################################################
#	Echo command and then do it AS ROOT.				#
#	Note that "ecsudo cd ..." will not do anything useful since the	#
#	shell with that updated CWD will immediately exit.		#
#########################################################################
#doc# ### ecsudo()
#doc# Print a command and execute it as a privileged user.
#doc# For most systems, this is using "sudo", but sudo does not exist on
#doc# Haiku and the user is operating essentially as administrator anyways.
ecsudo()
    {
    echo "! $@" >&2
    if in_path sudo ; then	# For most systems
        sudo "$@"
	return $?
    elif os_of HAIKU ; then	# Users are fully privileged
        "$@"
	return $?
    elif in_path /bin/su ; then	# Get ready to type root password
        su -c "$*"		# over and over and over again.
	return $?
    else			# I don't see this working except for Haiku
        "$@"			# For systems that require no privs
        return $?
    fi
    }

#########################################################################
#	Change directory (whether root or not)				#
#########################################################################
#doc# ### echocd()
#doc# Note that we're changing directory and do it.
echocd()
    {
    echo "[ Changing directory to $1 ]"
    #echodo cd "$1"
    cd "$1"
    }

#########################################################################
#	Look through OS to find out how it does things and leave	#
#	results in global variables.					#
#		OS_LIKE_(os)						#
#		INSTALLER						#
#########################################################################
os_variables()
    {
    if [ -f $USRLOCAL/etc/cpi_cfg.pl ] ; then
	WEBOFFSET=`perl -e 'eval(\`cat $USRLOCAL/etc/cpi_cfg.pl\`); print $cpi_vars::WEBOFFSET;'`
	echo INFO:  WEBOFFSET recovered:  $WEBOFFSET.
    else
        WEBOFFSET="/`date +%s |
	    if in_path sha1 ; then
	        sha1
	    elif in_path sha1sum ; then
	        sha1sum
	    elif in_path cksum ; then
	        cksum -a sha1 --base64 --untagged | tr -d +/=
	    else
	        cat -
	    fi | cut -c1-4`"
	echo INFO:  WEBOFFSET set to $WEBOFFSET.
    fi

    for sudodir in /etc/sudoers.d $USRLOCAL/etc/sudoers.d ; do
	if [ -d "$sudodir" ] ; then
	    SUDO_HACK="$sudodir/$PROG"
	    break
	fi
    done
    if [ -z "$SUDO_HACK" ] ; then
	echo "Cannot stop sudo from continually asking for your password."
    fi

    for try_installer in dnf yum apt-get pacman pkgadd pkg zypper pkgman; do
        if in_path $try_installer ; then
	    INSTALLER=$try_installer
	    case "$INSTALLER" in
		dnf)		INSTALLCMD="dnf -yq install";				OS_LIKE=REDHAT	;;
		yum)		INSTALLCMD="yum -yq install";				OS_LIKE=REDHAT	;;
		apt-get)	INSTALLCMD="apt-get install -qqy";			OS_LIKE=DEBIAN	;;
		pacman)		INSTALLCMD="pacman -S --noconfirm --noprogressbar";	OS_LIKE=ARCH	;;
		pkgadd)		INSTALLCMD="pkg install";				OS_LIKE=SOLARIS	;;
		pkg)		INSTALLCMD="pkg install -y";				OS_LIKE=FREEBSD	;;
		zypper)		INSTALLCMD="zypper install -y";				OS_LIKE=SUSE	;;
		pkgman)		INSTALLCMD="pkgman install -y";				OS_LIKE=HAIKU	;;
	    esac
	    break
	fi
    done
    [ -n "$INSTALLER" ] || fatal "Cannot find an installer."

    if os_of HAIKU ; then
        USRLOCAL=/boot/home/config/non-packaged
    else
        USRLOCAL=/usr/local
    fi
    
    export PATH=${PATH}:${USRLOCAL}/bin
    export PERL5LIB=${PERL5LIB}:${USRLOCAL}/lib/perl

    PROJECTS_DIR=$USRLOCAL/projects

    echo INFO:  OS_LIKE=$OS_LIKE INSTALLER=$INSTALLER INSTALLCMD=$INSTALLCMD

    if in_path gmake || os_of FREEBSD ; then
        GMAKE=gmake	# May not be installed yet
    else
        GMAKE=make	# May not be installed yet
    fi

    os_of FREEBSD && os_install coreutils
    GINSTALL=`command -v ginstall >/dev/null 2>&1`
    if [ -z "$GINSTALL" ] ; then
	GINSTALL=/usr/gnu/bin/install
	if [ ! -x "$GINSTALL" ] ; then
	    GINSTALL=$USRLOCAL/bin/ginstall
	    if [ ! -x "$GINSTALL" ] ; then
	        GINSTALL=install
	    fi
	fi
    fi

    echo INFO:  SUDO_HACK=$SUDO_HACK GMAKE=$GMAKE GINSTALL=$GINSTALL
    }

#########################################################################
#	Protect linux (BSD?) install utility from the nasty fact	#
#	that Haiku (and maybe others) has no /dev/stdin.		#
#########################################################################
#doc# ### suinstall()
#doc# Protect linux (BSD?) install utility from the nasty fact
#doc# that Haiku (and maybe others) has no /dev/stdin.  Just copy data
#doc# to a /tmp file and use that.
suinstall()
    {
    case "$*" in
        *" /dev/stdin "*)
	    if os_of FREEBSD HAIKU || [ ! -e /dev/stdin ] ; then
		cat > $TMP.stdin
		ecsudo $GINSTALL `echo "$@" | sed -e "s:/dev/stdin:$TMP.stdin:"`
		return $?
	    fi
    esac
    ecsudo $GINSTALL "$@"
    return $?
    }

#########################################################################
#	Turn off sudo asking passwords for the duration of the script.	#
#	There is a special place in hell for me.  I know it.		#
#########################################################################
#doc# ### temporarily_disable_sudo_password()
#doc# Since this script can take a while (due to update, installing CPAN modules),
#doc# temporarily update sudo configuration to not require passwords every 5 minutes.
temporarily_disable_sudo_password()
    {
    [ -z "$SUDO_HACK" ] ||
	echo "$USER ALL=(ALL) NOPASSWD: ALL" | \
	    suinstall -o $SYSTEM_USER -g $SYSTEM_GROUP -m 0444 /dev/stdin $SUDO_HACK
    }

#########################################################################
#	Make sure we're working on an uptodate system.			#
#########################################################################
#doc# ### performa_updates()
#doc# Do whatever os requires to be reasonably up to date
performa_updates()
    {
    echo "[ Performa updates ]"
    case "$INSTALLER" in
        dnf)			ecsudo dnf -yq update					;;
	yum)			ecsudo yum -yq update					;;
	apt-get)		ecsudo apt-get update -qqy; ecsudo apt-get upgrade -yqq	;;
	pacman)			ecsudo pacman -Syu --noconfirm --noprogressbar		;;
	pkgadd)			ecsudo pkg update					;;
	pkg)			ecsudo pkg update; ecsudo pkg upgrade			;;
	zypper)			ecsudo ecsudo zypper update				;;
	pkgman)			yes "" | ecsudo pkgman add https://eu.hpkg.haiku-os.org/haiku/r1beta5/$(getarch)/current
				ecsudo pkgman full-sync -y
				;;
    esac
    }

#########################################################################
#	Use the right installation tool					#
#########################################################################
#doc# ### os_install()
#doc# Figure out what tool is used to install and install specified packages
#doc# Note that it does this one package at a time because most of the
#doc# package handlers completely fail if one can't be installed and for
#doc# development purposes, we want to know what works, not just the first
#doc# thing that failed.  When these work across all of our development
#doc# platforms, it will probably go back to handing all the arguments to
#doc# the package installer at once.
os_install()
    {
    for p in $*; do
	ecsudo $INSTALLCMD $p
    done

    # ecsudo $INSTALLCMD $*
    }

#########################################################################
#	Setup to start working in PROJECTS_DIR				#
#########################################################################
#doc# ### setup_projects()
#doc# Setup directory structure for all the different cpi projects.
#doc# This will include installing make, gcc etc.
#doc# Made more complex due to Arch linux's lack of support for cpan.
#doc# We pretend cpanm acts just like cpan.  Hoping that doesn't cause
#doc# problems down the line.
setup_projects()
    {
    echo INFO:  Setting up projects.

    if os_of SOLARIS ; then
    	# Get version perl was compiled against and install that.
	# We need it for installing perl modules
    	perlver=`perl -V | awk -F/ '/cc=.\/usr\/gcc\// {print $4}'`
	echo "*** Using gcc version $perlver ***"
	os_install /developer/gcc-$perlver
    else
        os_install gcc
    fi
    os_install sox netpbm
    in_path $GMAKE || os_install $GMAKE
    if os_of HAIKU ; then
        : Do nothing
    elif os_of FREEBSD ; then
        os_install ghostscript10
    else
	os_install ghostscript
    fi

    if in_path trans ; then
        echo "Trans already installed.  Skipping system depending install logic."
    elif grep -sq 'NAME="Debian GNU/Linux"' /usr/lib/os-release ; then
	# This should probably just skip through to failsafe.
        echodo curl -s -o $TMP.deb 'http://http.us.debian.org/debian/pool/contrib/t/translate-shell/translate-shell_0.9.7.1-2_all.deb'
        os_install $TMP.deb
    elif os_of SOLARIS ; then
    	: Take the failsafe.
#	    mkdir $TMP.translate-shell
#	    echocd $TMP.translate-shell
#	    echodo git clone https://github.com/soimort/translate-shell
#	    echocd $TMP.translate-shell/translate-shell
#	    echodo $GMAKE prefix=/
#	    ecsudo $GMAKE install
    else
        os_install translate-shell
    fi

    if in_path trans ; then
        echo "We have an installed trans."
    else
    	# Fail safe.
	echodo curl -s https://raw.githubusercontent.com/soimort/translate-shell/gh-pages/trans | 
	    suinstall $SYSTEM_EXECUTABLE_ATTRIBUTES /dev/stdin $USRLOCAL/bin/trans
	[ -h /bin/trans ] || ecsudo ln -s $USRLOCAL/bin/trans /bin/trans
    fi

    in_path trans || echo "**** No working trans.  Translation will not work ****"

    in_path perl || os_install perl

    if [ ! -x /usr/bin/perl ] ; then
        where_is_perl=`command -v perl`
	[ -n "$where_is_perl" ] || fatal "No perl found.  Nothing will work.  Giving up."
	ecsudo ln -s "$where_is_perl" "/usr/bin/perl"
    fi

    CPAN=cpan
    if os_of ARCH ; then
    	os_install poppler cpanminus
        CPAN=/usr/bin/vendor_perl/cpanm
    elif os_of DEBIAN ; then
    	os_install poppler-utils libjpeg-dev
	[ -x $USRLOCAL/bin/cpan ] || os_install cpan
    elif os_of REDHAT ; then
    	os_install poppler-utils script cpan
    fi

    export PERL_MM_USE_DEFAULT=1
    export PERL_MM_NONINTERACTIVE=1
    yes "" | ecsudo $CPAN -i CPAN

    if os_of HAIKU ; then
        $CPAN -i -f CPAN::DistnameInfo
	$CPAN -i -f Email::Date::Format
	$CPAN -i -f MIME::Lite
    fi

    ecsudo $CPAN -i Imager/File/JPEG.pm Date/Manip.pm
    if os_of FREEBSD ; then
        os_install databases/gdbm-GDBM p5-GDBM
	ecsudo $CPAN -i B::COW
	ecsudo $CPAN rm -rf /root/.cpan/build/ATOOMIC-*
	echo ""
	echo "*** The following will fail but its corpse will be useful ***"
	ecsudo $CPAN -i Clone
	echo ""
	echo "OK, CPAN failed due to tar exiting with non-zero exit status"
	echo "due to FreeBSD file attribute issues.  make and install by hand:"
	os_install gcc		# We need this for make
	ecsudo chmod o+x /root
	echocd /root/.cpan/build/ATOOMIC-0/Clone-0.48
	ecsudo perl Makefile.PL
	ecsudo make		# Note that this is Berkeley (bmake), not gmake
	ecsudo make test
	ecsudo make install
	ecsudo chmod o-x /root
	echocd /
	echo "With a little luck, we now have a working Clone used by CAPTCHA."
    elif os_of HAIKU ; then
	echo "**** Cannot install GDBM_File on haiku ****"
        : ecsudo $CPAN -i GDBM_File
    fi

    if [ ! -e /usr/lib/sendmail ] ; then
	os_install ssmtp
	like DEBIAN && os_install mailutils
    fi
    suinstall $SYSTEM_DIRECTORY_ATTRIBUTES $PROJECTS_DIR
    res=$?
    echo INFO:  setup_projects returns $res.
    return $res
    }

#########################################################################
#	Decide what web server is appropriate and get it going.		#
#########################################################################
#doc# ### install_and_configure_a_web_server()
#doc# Figure out correct web server to install, configure that server and make sure it
#doc# it can be accessed if there is a local firewall.
install_and_configure_a_web_server()
    {
    cgi_module=modules/mod_cgi.so
    if os_of REDHAT ; then
	service=httpd.service
	HTTP_CPI_CFG=/etc/httpd/conf.d/cpi.conf
    	os_install httpd
    elif os_of DEBIAN ; then
        os_install apache2
	service=apache2
	HTTP_CPI_CFG=/etc/apache2/conf-enabled/cpi.conf
	[ -h /etc/apache2/mods-enabled/cgi.load ] || \
	    ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
    elif os_of SUSE ; then
	os_install apache2
	service=apache2
	HTTP_CPI_CFG=/etc/apache2/conf.d/cpi.conf
    elif os_of ARCH ; then
	service=httpd
	HTTP_CPI_CFG=/etc/httpd/conf/conf.d/cpi.conf
    	os_install apache
    elif os_of HAIKU ; then
	HTTP_CPI_CFG=/boot/system/settings/apache/httpd.conf
        os_install apache
    elif os_of FREEBSD ; then
	os_install apache24
	grep -s apache24_enable /etc/rc.conf ||
	    ecsudo sysrc 'apache24_enable=YES'
	HTTP_CPI_CFG=$USRLOCAL/etc/apache24/Includes/cpi.conf
        cgi_module=libexec/apache24/mod_cgi.so
    elif os_of SOLARIS ; then
        os_install apache-24
	HTTP_CPI_CFG=/etc/apache2/2.4/conf.d/cpi.conf
        cgi_module=libexec/mod_cgi.so
	# Log in /var/svc/log/network-http:apache24.log
    fi

    for DOCUMENTROOT in /var/www/www /var/www/html /srv/http /srv/www/htdocs /boot/system/data/apache/htdocs $USRLOCAL/www/apache24/data /var/apache2/2.4/htdocs ; do
	if [ -d $DOCUMENTROOT ] ; then
	    WEBTOP=$DOCUMENTROOT$WEBOFFSET
	    break
	fi
    done

    [ -n "$WEBTOP" ] || fatal "No documentroot found."

    suinstall $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $HTTP_CPI_CFG <<EOF
LoadModule cgi_module $cgi_module
AddHandler cgi-script .cgi .pl
<Directory $WEBTOP>
    DirectoryIndex index.cgi index.html
    Options +ExecCGI +FollowSymlinks
</Directory>
EOF

    if [ -n "$service" ] ; then
	ecsudo systemctl enable $service
	ecsudo systemctl start $service
	ecsudo systemctl reload $service	# This should really not be needed
    elif os_of FREEBSD ; then
	ecsudo service apache24 start
    elif os_of SOLARIS ; then
        ecsudo svcadm enable apache24
    fi

    # Can't do this before we've installed the http server
    WUSER=`awk -F: '/^(apache|www|www-data|http|wwwrun|webservd)/ {print $3}' /etc/passwd`
    WGROUP=`awk -F: '/^(apache|www|www-data|http|wwwrun|webservd)/ {print $4}' /etc/passwd`

    WUSER=${WUSER:-user}
    WGROUP=${WGROUP:-users}

    suinstall -d -m 0755 -o $WUSER -g $WGROUP $WEBTOP

    if [ -x /usr/bin/firewall-cmd ] ; then
	ecsudo firewall-cmd --zone=public --add-service=http --permanent
	ecsudo systemctl reload firewalld.service
    fi

    if [ -f /etc/selinux/config ] ; then
	if $DISABLE_SELINUX ; then
            ecsudo grubby --update-kernel ALL --args selinux=0
	    REBOOT_REASON="$REBOOT_REASON~Kernel flag selinux set to 0."
	else
	    ecsudo semanage fcontext -a -t httpd_sys_script_exec_t "$WEBTOP(/.*)?"   
	    suinstall -d -m 0777 -o $WUSER -g $WGROUP /var/log/stderr
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/stderr(/.*)?"
	    suinstall -m 0666 -o $WUSER -g $WGROUP /var/log/common.log
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/common.log"
	    ecsudo restorecon -Rv $WEBTOP
    	fi
    fi

    OVERRIDECONF=/etc/systemd/system/httpd.service.d/override.conf
    if [ -d `dirname $OVERRIDECONF` -a ! -s $OVERRIDECONF ] ; then
        suinstall $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $OVERRIDECONF <<EOF
[Service]
ProtectSystem=no
ProtectHome=no
EOF
        REBOOT_REASON="$REBOOT_REASON~ProtectSystem disabled in systemd config."
    fi

    echo "[Web software will be installed into ${WEBTOP}]"

    if [ ! -f $USRLOCAL/etc/cpi_cfg.pl ] ; then
	suinstall $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $USRLOCAL/etc/cpi_cfg.pl <<EOF
#\$cpi_vars::WEBOFFSET="YourDomain.com";
#\$cpi_vars::FAX_SERVER="Your fax printer name";
#\$cpi_vars::KEY_CAPTCHA_PUBLIC="Captcha public key";
#\$cpi_vars::KEY_CAPTCHA_PRIVATE="Captcha private key";
\$cpi_vars::WEBOFFSET="$WEBOFFSET";
\$cpi_vars::WEBTOP="$WEBTOP";
EOF
    fi
    echo INFO:  install_and_configure_a_web_server WEBTOP=$WEBTOP.
    return $?
    }

#########################################################################
#	Git clone into a specified directory (managing rootness)	#
#########################################################################
#doc# ### git_clone_to()
#doc# Get project from github and put it in $USRLOCAL/projects.
git_clone_to()
    {
    git_url="$1"
    dest_dir="$2"
    if [ -d "$dest_dir/.git" ] ; then
	echocd $dest_dir
	echodo git pull
	res=$?
    else
	suinstall -m 0755 -d -o $USER -g $GROUP $dest_dir
	echocd `dirname $dest_dir`
	echodo git clone -q "$git_url"
	res=$?
	echocd $dest_dir
    fi
    [ 0 = $? ] || echo INFO:  get_clone_to $dest_dir returns $res.
    return $res
    }

#########################################################################
#	Install generic project software.				#
#	Note that if no url is provided, we'll see if we can ssh it.	#
#	Otherwise, we'll use the public address.			#
#########################################################################
#doc# ### install_and_configure()
#doc# Populate $USRLOCAL/projects/PROJECT and "make install" in that directory.
install_and_configure()
    {
    project="$1"
    url="$2"
    if [ -z "$url" ] ; then
        if [ -r "$HOME/.ssh/github.com/$project-ro.pub" ] ; then
	    url="git@github.com-$project-ro:dufflerpud/$project.git"
	else
    	    url="https://github.com/dufflerpud/$project.git"
	fi
    fi
    echo "[ Installing and configuring $project ]"
    top_proj_dir=$PROJECTS_DIR/$project
    git_clone_to "$url" "$top_proj_dir"
    echocd $top_proj_dir
    ecsudo $GMAKE install
    res=$?
    echo INFO:  install_and_configure $dest_dir returns $res.
    return $res
    }

#########################################################################
#	Bring over the files we need to access github and the rest of	#
#	the world							#
#########################################################################
#doc# ### setup_communication()
#doc# For developer only - grab a script from a local host and run it.
setup_communication()
    {
    ssh 10.1.0.20 sh $USRLOCAL/projects/START_HERE/developer.sh | sh
    res=$?
    echo INFO:  setup_communication returns $res.
    return $res
    }

#########################################################################
#	Multis written in Fortran-66 so we need f2c, and also curses.	#
#########################################################################
#doc# ### setup_multis()
#doc# Find and install f2c (Fortran-to-C filter)
setup_multis()
    {
    # Need f2c and curses for multis
    if in_path f2c ; then
	# It either came as part of the distribution or the above
	# system-by-system logic built it.
	echo "f2c is already installed.  Skipping system dependent install logic."
    elif os_of DEBIAN REDHAT SUSE FREEBSD ; then
	# These systems don't come with it installed but they know of it
	os_install f2c
    elif os_of ARCH ; then
	os_install base-devel
	git_clone_to https://aur.archlinux.org/f2c.git $TMP.build/f2c
	yes | echodo makepkg -srif --noprogressbar
    else
	# Else build it from the source.  Hail Mary ... (Solaris)
	git_clone_to https://github.com/barak/f2c $TMP.build/f2c
	echocd $TMP.build/f2c/src
	echodo $GMAKE -f makefile.u f2c CC=gcc
	suinstall $SYSTEM_EXECUTABLE_ATTRIBUTES f2c $USRLOCAL/bin/f2c
    fi
    echocd $HOME

    if os_of DEBIAN ; then
	os_install libncurses-dev
    elif os_of REDHAT SUSE ; then
	os_install ncurses-devel
    fi

    in_path f2c	# Return status used to decide to build multis
    res=$?
    echo INFO:  setup_multis returns $res.
    return $res
    }

#########################################################################
#	Print an error message and die.					#
#########################################################################
#doc# ### fatal()
#doc# Print an error message and exit.
fatal()
    {
    echo "$*" >&2
    exit 1
    }

#########################################################################
#	Print a USEFUL error message ... and die.			#
#########################################################################
#doc# ### usage()
#doc# Print a useful error message and die.
usage()
    {
    echo "$*" | tr ~ '\n' >&2
    fatal "Usage:  $PROG [-clean]"
    }

#########################################################################
#	Get rid of the travesty we created for doing things as root.	#
#########################################################################
#doc# ### cleanup()
#doc# Remove any temporary files and sudo hack to allow normal sudo behavior
cleanup()
    {
    [ -z "$SUDO_HACK" ] || ecsudo rm -f $SUDO_HACK
    }

#########################################################################
#	Main								#
#########################################################################
#doc# ### Main
#doc# Parse arguments and then install packages in a reasonable order.
#doc# Note that you need to setup_projects and install cpi and common
#doc# before anything else.

while [ "$#" -gt 0 ] ; do
    case "$1" in
	-c*)	BE_CLEAN=true					;;
	-d*)	DEVELOPER=true					;;
	-s*)	DISABLE_SELINUX=false				;;
	-w*)	WEBOFFSET="$2"; shift				;;
	*)	PROBLEMS="${PROBLEMS}Unknown argument [$1]~"	;;
    esac
    shift
done

[ -z "$PROBLEMS" ] || usage "$PROBLEMS"

os_variables

umask 002
export TZ=`date +%Z`	# Required for Fedora install of TimeDate.pm etc

temporarily_disable_sudo_password
trap cleanup EXIT

performa_updates
os_install git
in_path hostname || os_install inetutils
install_and_configure_a_web_server

$BE_CLEAN && ecsudo rm -rf ${WEBTOP} ${PROJECTS_DIR} $USRLOCAL/etc/cpi_cfg.pl /etc/ssmtp/ssmtp.conf

setup_projects
install_and_configure START_HERE	# Requires setup projects
install_and_configure cpi		# Requires setup_projects
install_and_configure common		# Requires cpi already be setup
install_and_configure busybox		# Requires common
install_and_configure User		# Requires cpi & common
install_and_configure Slide_Show	# Requires cpi & common
install_and_configure pictures		# Requires cpi & common
install_and_configure testd		# Requires cpi & common
install_and_configure ww		# Requires cpi & common
install_and_configure Antasgo		# Requires cpi & common
install_and_configure Groceries		# Requires cpi & common
install_and_configure routing		# Requires cpi & common

install_and_configure simple_utils	# Requires cpi & common
install_and_configure todo		# Requires cpi & common
install_and_configure table_fun		# Requires cpi & common
install_and_configure set_screen	# Requires cpi & common
install_and_configure sudoku		# Requires cpi & common
install_and_configure rank_vote		# Requires cpi & common
install_and_configure diagnosis		# Requires cpi & common
install_and_configure Visas		# Requires cpi & common
install_and_configure activist		# Requires cpi & common
install_and_configure sign		# Requires cpi & common
install_and_configure cci		# Requires common, gcc
install_and_configure pandemic		# Requires cpi, common, cci and gcc

# Requires cpi, gcc, f2c, curses
setup_multis && install_and_configure multis

if $DEVELOPER ; then
    setup_communication
    install_and_configure websh		# Requires cpi & common
fi

if [ -n "$REBOOT_REASON" ] ; then
    echo "REASON TO REBOOT:$REBOOT_REASON" | sed -e 's/~/\n    /g'
fi

exec $USRLOCAL/projects/START_HERE/check_install.sh
ecsudo rm -rf $TMP.*
