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

case "$0" in
    -*)		PROG=Install_and_Build	;;	# Happens with FreeBSD
    *)		PROG=`basename $0 .sh`	;;
esac

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
#	Returns if $OSV_LIKE is the specified argument.			#
#########################################################################
#doc# ### os_of()
#doc# Return true if the current OS is any of the arguments
os_of()
    {
    echo " $* " | grep -iq " $OSV_LIKE "
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
    $OSV_SUDO "$@"
    return $?
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
#########################################################################
os_variables()
    {
    OSV_USRLOCAL=/usr/local
    OSV_SUDO=sudo
    OSV_WS_CGIMODULE=modules/mod_cgi.so
    OSV_WS_DOCUMENTROOT=/var/www/html

    export PATH=${PATH}:/sbin:/usr/sbin
    for try_installer in dnf yum apt-get pacman pkgadd pkg zypper pkgman slackpkg emerge ; do
        if in_path $try_installer ; then
	    OSV_PKG_APP=$try_installer
	    case "$OSV_PKG_APP" in
		dnf|yum)	OSV_LIKE=REDHAT
				OSV_INSTALL="$OSV_PKG_APP -yq install"
				OSV_UPDATE="$OSV_PKG_APP -yq update"
				OSV_WS_CPICFG=/etc/httpd/conf.d/cpi.conf
				OSV_WS_SYSTEMCTL=httpd.service
				OSV_WS_PKG=httpd
				;;
		apt-get)	OSV_LIKE=DEBIAN
				OSV_INSTALL="$OSV_PKG_APP install -qqy"
				OSV_UPDATE="$OSV_PKG_APP update -qqy"
				OSV_UPGRADE="$OSV_PKG_APP upgrade -yqq"
				OSV_WS_CPICFG=/etc/apache2/conf-enabled/cpi.conf
				OSV_WS_SYSTEMCTL=apache2
				OSV_WS_PKG=$OSV_WS_SYSTEMCTL
				[ -h /etc/apache2/mods-enabled/cgi.load ] || \
				    ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
				;;
		zypper)		OSV_LIKE=SUSE
				OSV_INSTALL="$OSV_PKG_APP install -y"
				OSV_UPDATE="$OSV_PKG_APP update"
				OSV_WS_CPICFG=/etc/apache2/conf.d/cpi.conf
				OSV_WS_SYSTEMCTL=apache2
				OSV_WS_PKG=$OSV_WS_SYSTEMCTL
				OSV_WS_DOCUMENTROOT=/srv/www/htdocs
				;;
		pacman)		OSV_LIKE=ARCH
				OSV_INSTALL="$OSV_PKG_APP -S --noconfirm --noprogressbar"
				OSV_UPDATE="$OSV_PKG_APP -Syu --noconfirm --noprogressbar"
				OSV_WS_CPICFG=/etc/httpd/conf/conf.d/cpi.conf        
				OSV_WS_SYSTEMCTL=httpd
				OSV_WS_PKG=apache 
				OSV_WS_DOCUMENTROOT=/srv/http
				;;
		pkgadd)		OSV_LIKE=SOLARIS
				OSV_INSTALL="pkg install"
				OSV_UPDATE="pkg update"
				OSV_WS_CPICFG=/etc/apache2/2.4/conf.d/cpi.conf
				OSV_WS_PKG=apache-24
				OSV_WS_CGIMODULE=libexec/mod_cgi.so
				OSV_WS_DOCUMENTROOT=/var/apache2/2.4/htdocs
				OSV_WS_SVCADM=apache24
				# Log in /var/svc/log/network-http:apache24.log
				;;
		pkg)		OSV_LIKE=FREEBSD
				OSV_INSTALL="$OSV_PKG_APP install -y"
				OSV_UPDATE="$OSV_PKG_APP update"
				OSV_UPGRADE="$OSV_PKG_APP upgrade -y"
				OSV_WS_CPICFG=/etc/apache2/2.4/conf.d/cpi.conf
				OSV_WS_PKG=apache-24
				OSV_WS_CGIMODULE=libexec/mod_cgi.so
				OSV_WS_DOCUMENTROOT=/usr/local/www/apache24/data
				OSV_WS_SERVICE=apache24
				;;
		pkgman)		OSV_LIKE=HAIKU
				OSV_INSTALL="pkgman install -y"
				OSV_SYNC="$OSV_PKG_APP add https://eu.hpkg.haiku-os.org/haiku/r1beta5/$(getarch)/current"
				OSV_UPDATE="$OSV_PKG_APP full-sync -y"
				OSV_USRLOCAL=/boot/home/config/non-packaged
				OSV_SUDO=
				OSV_WS_CPICFG=/boot/system/settings/apache/extra/cpi.conf
				OSV_WS_CGIMODULE=lib/apache/mod_cgi.so
				OSV_WS_PKG=apache
				OSV_WS_DOCUMENTROOT=$OSV_USRLOCAL/htdocs
				OSV_WS_HTTPDCONF=/boot/system/settings/apache/httpd.conf
				OSV_WS_INCLUDE="Include $OSV_WS_CPICFG"
				;;
		slackpkg)	OSV_LIKE=SLACKWARE
				OSV_INSTALL="$OSV_PKG_APP install -y"
				OSV_UPDATE="$OSV_PKG_APP update -y"
				OSV_WS_CPICFG=/etc/httpd/extra/cpi.conf
				OSV_WS_CGIMODULE=lib64/httpd/modules/mod_cgi.so
				OSV_WS_DOCUMENTROOT=/srv/httpd/htdocs
				OSV_WS_HTTPDCONF=/etc/httpd/httpd.conf
				OSV_WS_INCLUDE="Include $OSV_WS_CPICFG"
				;;
		emerge)		OSV_LIKE=GENTOO
				OSV_INSTALL="$OSV_PKG_APP -q"
				OSV_SYNC="emaint sync -a"
				OSV_UPDATE="$OSV_PKG_APP --update --deep --newuse @world"
				OSV_WS_SYSTEMCTL=apache2
				OSV_WS_PKG="www-servers/apache"
				OSV_WS_CPICFG=/etc/apache2/vhosts.d/cpi.conf
				OSV_WS_DOCUMENTROOT=/var/www/localhost/htdocs
				;;
	    esac
	    break
	fi
    done
    [ -n "$OSV_PKG_APP" ] || fatal "Cannot find an installer."

    export PATH=${PATH}:${OSV_USRLOCAL}/bin
    export PERL5LIB=${PERL5LIB}:${OSV_USRLOCAL}/lib/perl

    PROJECTS_DIR=$OSV_USRLOCAL/projects

    if [ -f $OSV_USRLOCAL/etc/cpi_cfg.pl ] ; then
	OSV_WS_OFFSET=`perl -e 'eval(\`cat $OSV_USRLOCAL/etc/cpi_cfg.pl\`); print $cpi_vars::WEBOFFSET;'`
	echo INFO:  OSV_WS_OFFSET recovered:  $OSV_WS_OFFSET.
    else
        OSV_WS_OFFSET="/`date +%s |
	    if in_path sha1 ; then
	        sha1
	    elif in_path sha1sum ; then
	        sha1sum
	    elif in_path cksum ; then
	        cksum -a sha1 --base64 --untagged | tr -d +/=
	    else
	        cat -
	    fi | cut -c1-4`"
	echo INFO:  OSV_WS_OFFSET set to $OSV_WS_OFFSET.
    fi

    OSV_WS_TOP=$OSV_WS_DOCUMENTROOT$OSV_WS_OFFSET

    set | grep '^OSV' | sed -e 's/.*OSV/INFO: OSV/'

    for sudodir in /etc/sudoers.d $OSV_USRLOCAL/etc/sudoers.d ; do
	[ -d "$sudodir" ] && SUDO_HACK="$sudodir/$PROG"
    done
    if [ -z "$SUDO_HACK" ] ; then
	echo "Cannot stop sudo from continually asking for your password."
    fi

    echo INFO:  OSV_LIKE=$OSV_LIKE OSV_PKG_APP=$OSV_PKG_APP OSV_INSTALL=$OSV_INSTALL

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
	    GINSTALL=$OSV_USRLOCAL/bin/ginstall
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
    [ -z "$OSV_SYNC" ]		|| yes '' | ecsudo $OSV_SYNC	# HAIKU, GENTOO
    [ -z "$OSV_UPDATE" ]	|| ecsudo $OSV_UPDATE		# Everybody
    [ -z "$OSV_UPGRADE" ]	|| ecsudo $OSV_UPGRADE		# DEBIAN, FREEBSD
    }

#########################################################################
#	Use the right installation tool					#
#########################################################################
#doc# ### os_install()
#doc# Install a package using the OS package installer.
#doc# Note that it does this one package at a time because most of the
#doc# package handlers completely fail if one can't be installed and for
#doc# development purposes, we want to know what works, not just the first
#doc# thing that failed.  When these work across all of our development
#doc# platforms, it will probably go back to handing all the arguments to
#doc# the package installer at once.
os_install()
    {
    for p in $*; do
	ecsudo $OSV_INSTALL $p
    done

    # ecsudo $OSV_INSTALL $*
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
    elif os_of SLACKWARE ; then
	echo "(Gcc already installed, skipping)"
    else
        os_install gcc
    fi
    os_install sox netpbm
    in_path $GMAKE || os_install $GMAKE
    if os_of HAIKU ; then
        os_install ghostscript_gpl
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
	    suinstall $SYSTEM_EXECUTABLE_ATTRIBUTES /dev/stdin $OSV_USRLOCAL/bin/trans
	[ -h /bin/trans ] || ecsudo ln -s $OSV_USRLOCAL/bin/trans /bin/trans
    fi

    in_path trans || echo "**** No working trans.  Translation will not work ****"

    in_path perl || os_install perl

    if [ ! -x /usr/bin/perl ] ; then
        where_is_perl=`command -v perl`
	[ -n "$where_is_perl" ] || fatal "No perl found.  Nothing will work.  Giving up."
	# This won't work on Haiku
	ecsudo ln -s "$where_is_perl" "/usr/bin/perl"
    fi

    CPAN=cpan
    if os_of ARCH ; then
    	os_install poppler cpanminus
        CPAN=/usr/bin/vendor_perl/cpanm
    elif os_of DEBIAN ; then
    	os_install poppler-utils libjpeg-dev
	[ -x $OSV_USRLOCAL/bin/cpan ] || os_install cpan
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
    [ -z "$OSV_WS_PKG" ] || os_install $OSV_WS_PKG

    case "$OSV_LIKE" in
	DEBIAN)		[ -h /etc/apache2/mods-enabled/cgi.load ] || \
			    ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
			;;
	FREEBSD)	grep -s apache24_enable /etc/rc.conf ||
			    ecsudo sysrc 'apache24_enable=YES'
			;;
	SOLARIS)	# Log in /var/svc/log/network-http:apache24.log
			;;
	SLACKWARE)	grep -q "$OSV_WS_CPICFG" /etc/httpd/httpd.conf ||
			    echo "Include /etc/httpd/extra/cpi.conf" >> /etc/httpd/httpd.conf
			;;
	HAIKU)		ecsudo ln -s /bin/httpd /boot/home/config/settings/boot/launch/httpd
			;;
    esac

    suinstall $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $OSV_WS_CPICFG <<EOF
LoadModule cgi_module $OSV_WS_CGIMODULE
AddHandler cgi-script .cgi .pl
<Directory $OSV_WS_TOP>
    DirectoryIndex index.cgi index.html
    Options +ExecCGI +FollowSymlinks
</Directory>
EOF

    if [ -n "$OSV_WS_HTTPDCONF" ] ; then
        if grep -vq "$OSV_WS_INCLUDE" "$OSV_WS_HTTPDCONF" ; then
	    ecsudo cp -f $OSV_WS_HTTPDCONF $OSV_WS_HTTPDCONF.dist
	    (
	    sed -e "s+\"/boot/system/data/apache/htdocs\"+\"$OSV_WS_DOCUMENTROOT\"+" $OSV_WS_HTTPDCONF.dist
	    echo "$OSV_WS_INCLUDE"
	    ) | ecsudo dd of=$OSV_WS_HTTPDCONF
	else
	    echo "$OSV_WS_HTTPDCONF already updated."
	fi
    fi

    if [ -n "$OSV_WS_SYSTEMCTL" ] ; then
	ecsudo systemctl enable $OSV_WS_SYSTEMCTL
	ecsudo systemctl start $OSV_WS_SYSTEMCTL
	ecsudo systemctl reload $OSV_WS_SYSTEMCTL	# This should really not be needed
    elif [ -n "$OSV_WS_SERVICE" ] ; then
        ecsudo service $OSV_WS_SERVICE start
    elif [ -n "$OSV_WS_SVCADM" ] ; then
        ecsudo svcadm enable $OSV_WS_SVCADM
    elif in_path apachectl ; then
        ecsudo apachectl restart
    fi

    # Can't do this before we've installed the http server
    WUSER=`awk -F: '/^(apache|www|www-data|http|wwwrun|webservd)/ {print $3}' /etc/passwd`
    WGROUP=`awk -F: '/^(apache|www|www-data|http|wwwrun|webservd)/ {print $4}' /etc/passwd`

    WUSER=${WUSER:-user}
    WGROUP=${WGROUP:-users}

    suinstall -d -m 0755 -o $WUSER -g $WGROUP $OSV_WS_TOP

    if [ -x /usr/bin/firewall-cmd ] ; then
	ecsudo firewall-cmd --zone=public --add-service=http --permanent
	ecsudo systemctl reload firewalld.service
    fi

    if [ -f /etc/selinux/config ] ; then
	if $DISABLE_SELINUX ; then
            ecsudo grubby --update-kernel ALL --args selinux=0
	    REBOOT_REASON="$REBOOT_REASON~Kernel flag selinux set to 0."
	else
	    ecsudo semanage fcontext -a -t httpd_sys_script_exec_t "$OSV_WS_TOP(/.*)?"   
	    suinstall -d -m 0777 -o $WUSER -g $WGROUP /var/log/stderr
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/stderr(/.*)?"
	    suinstall -m 0666 -o $WUSER -g $WGROUP /var/log/common.log
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/common.log"
	    ecsudo restorecon -Rv $OSV_WS_TOP
    	fi
    fi

    OVERRIDECONF=/etc/systemd/system/$OSV_WS_SYSTEMCTL.service.d/override.conf
    if [ -d /etc/systemd -a ! -s $OVERRIDECONF ] ; then
        suinstall -D $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $OVERRIDECONF <<EOF
[Service]
ProtectSystem=no
ProtectHome=no
EOF
        REBOOT_REASON="$REBOOT_REASON~ProtectSystem disabled in systemd config."
    fi

    echo "[Web software will be installed into ${OSV_WS_TOP}]"

    if [ ! -f $OSV_USRLOCAL/etc/cpi_cfg.pl ] ; then
	suinstall $SYSTEM_READABLE_ATTRIBUTES /dev/stdin $OSV_USRLOCAL/etc/cpi_cfg.pl <<EOF
#\$cpi_vars::DOMAIN="YourDomain.com";
#\$cpi_vars::FAX_SERVER="Your fax printer name";
#\$cpi_vars::KEY_CAPTCHA_PUBLIC="Captcha public key";
#\$cpi_vars::KEY_CAPTCHA_PRIVATE="Captcha private key";
\$cpi_vars::WEBOFFSET="$OSV_WS_OFFSET";
\$cpi_vars::WEBTOP="$OSV_WS_TOP";
EOF
    fi
    echo INFO:  install_and_configure_a_web_server OSV_WS_TOP=$OSV_WS_TOP.
    return $?
    }

#########################################################################
#	Git clone into a specified directory (managing rootness)	#
#########################################################################
#doc# ### git_clone_to()
#doc# Get project from github and put it in $OSV_USRLOCAL/projects.
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
#doc# Populate $OSV_USRLOCAL/projects/PROJECT and "make install" in that directory.
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
    ecsudo $GMAKE install && ecsudo $GMAKE test
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
    ssh 10.1.0.20 sh $OSV_USRLOCAL/projects/START_HERE/developer.sh | sh
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
	suinstall $SYSTEM_EXECUTABLE_ATTRIBUTES f2c $OSV_USRLOCAL/bin/f2c
    fi
    echocd $HOME

    if os_of DEBIAN ; then
	os_install libncurses-dev
    elif os_of REDHAT SUSE ; then
	os_install ncurses-devel
    elif os_of HAIKU ; then
	os_install ncurses6_devel
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

$BE_CLEAN && ecsudo rm -rf ${WEBTOP} ${PROJECTS_DIR} $OSV_USRLOCAL/etc/cpi_cfg.pl /etc/ssmtp/ssmtp.conf

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

exec $OSV_USRLOCAL/projects/START_HERE/check_install.sh
ecsudo rm -rf $TMP.*
