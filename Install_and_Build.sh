#!/bin/sh
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
WUSER=`awk -F: '/^(apache|www-data|http)/ {print $3}' /etc/passwd`
WGROUP=`awk -F: '/^(apache|www-data|http)/ {print $4}' /etc/passwd`

PROJECTS_DIR=/usr/local/projects
BE_CLEAN=false
DEVELOPER=false
if [ -f /etc/cpi_cfg.pl ] ; then
    WEBOFFSET=`perl -e 'eval(\`cat /etc/cpi_cfg.pl\`); print $cpi_vars::WEBOFFSET;'`
else
    WEBOFFSET=/`date +%s | cksum -a sha1 --base64 --untagged | tr -d +/= | cut -c1-4`
fi
SUDO_HACK=/etc/sudoers.d/$PROG

LIKE_DEBIAN=false;	[ -x /bin/apt ] && LIKE_DEBIAN=true
LIKE_REDHAT=false;	[ -x /bin/dnf ] && LIKE_REDHAT=true
LIKE_ARCH=false;	[ -x /bin/pacman ] && LIKE_ARCH=true

DISABLE_SELINUX=true
REBOOT_REASON=
TMP=/tmp/$PROG

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
#	Turn off sudo asking passwords for the duration of the script.	#
#	There is a special place in hell for me.  I know it.		#
#########################################################################
#doc# ### temporarily_disable_sudo_password()
#doc# Since this script can take a while (due to update, installing CPAN modules),
#doc# temporarily update sudo configuration to not require passwords every 5 minutes.
temporarily_disable_sudo_password()
    {
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | \
	ecsudo install -o root -g root -m 0444 /dev/stdin $SUDO_HACK
    }

#########################################################################
#	Echo command and then do it AS ROOT.				#
#	Note that "ecsudo cd ..." will not do anything useful since the	#
#	shell with that updated CWD will immediately exit.		#
#########################################################################
#doc# ### ecsudo()
#doc# Print a command and execute it via sudo
ecsudo()
    {
    echo "! $@" >&2
    sudo "$@"
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
#	Make sure we're working on an uptodate system.			#
#########################################################################
#doc# ### performa_updates()
#doc# Do whatever os requires to be reasonably up to date
performa_updates()
    {
    echo "[ Performa updates ]"
    if [ -x /bin/dnf ] ; then
        ecsudo dnf -yq update
    elif [ -x /bin/apt ] ; then
	ecsudo apt update -yqq
	ecsudo apt upgrade -yqq
    elif [ -x /usr/bin/pacman ] ; then
        ecsudo pacman -Syu --noconfirm --noprogressbar
    else
        echo "Unable to update this OS, continuing."
    fi
    }

#########################################################################
#	Use the right installation tool					#
#########################################################################
#doc# ### osinstall()
#doc# Figure out what tool is used to install and install specified packages
osinstall()
    {
    if [ -x /bin/dnf ] ; then
        ecsudo dnf -yq install $*
    elif [ -x /bin/apt ] ; then
        ecsudo apt install -qqy $*
    elif [ -x /usr/bin/pacman ] ; then
        ecsudo pacman -S --noconfirm --noprogressbar $*
    else
        echo "Unable to install:  " $*
	exit 1
    fi
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
    echo "[ Setting up projects ]"
    osinstall make gcc sox ghostscript netpbm

    if grep -s 'NAME="Debian GNU/Linux"' /usr/lib/os-release >/dev/null 2>&1 ; then
        echodo curl -o $TMP.deb 'http://http.us.debian.org/debian/pool/contrib/t/translate-shell/translate-shell_0.9.7.1-2_all.deb'
        osinstall $TMP.deb
    else
        osinstall translate-shell
    fi

    CPAN=cpan
    if $LIKE_ARCH ; then
    	osinstall poppler cpanminus
        CPAN=/usr/bin/vendor_perl/cpanm
    elif $LIKE_DEBIAN ; then
    	osinstall poppler-utils libjpeg-dev
	[ -x /usr/local/bin/cpan ] || osinstall cpan
    elif $LIKE_REDHAT ; then
    	osinstall poppler-utils script cpan
    fi

    ecsudo PERL_MM_USE_DEFAULT=1 $CPAN -i CPAN
    ecsudo $CPAN -i HTTP::Date	# Required for Fedora due to timezone issues
    ecsudo $CPAN -i Imager/File/JPEG.pm Date/Manip.pm

    if [ ! -e /usr/lib/sendmail ] ; then
	osinstall ssmtp
	$LIKE_DEBIAN && osinstall mailutils
    fi
    ecsudo install -d -m 0755 -o root -g root ${PROJECTS_DIR}
    }

#########################################################################
#	Decide what web server is appropriate and get it going.		#
#########################################################################
#doc# ### install_and_configure_a_web_server()
#doc# Figure out correct web server to install, configure that server and make sure it
#doc# it can be accessed if there is a local firewall.
install_and_configure_a_web_server()
    {
    if $LIKE_REDHAT ; then
	service=httpd.service
	HTTP_CPI_CFG=/etc/httpd/conf.d/cpi.conf
    	osinstall httpd
    elif $LIKE_DEBIAN ; then
        osinstall apache2
	service=apache2
	HTTP_CPI_CFG=/etc/apache2/conf-enabled/cpi.conf
	[ -h /etc/apache2/mods-enabled/cgi.load ] || \
	    ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
    elif $LIKE_ARCH ; then
	service=httpd
	HTTP_CPI_CFG=/etc/httpd/conf/conf.d/cpi.conf
    	osinstall apache
    fi

    for DOCUMENTROOT in /var/www/www /var/www/html /srv/http; do
	if [ -d $DOCUMENTROOT ] ; then
	    WEBTOP=$DOCUMENTROOT$WEBOFFSET
	    break
	fi
    done

    if [ -z "$WEBTOP" ] ; then
	echo "No documentroot found."
	exit 1
    fi

    ecsudo install -o root -g root -m 0644 /dev/stdin $HTTP_CPI_CFG <<EOF
LoadModule cgi_module modules/mod_cgi.so
AddHandler cgi-script .cgi .pl
<Directory $WEBTOP>
    DirectoryIndex index.cgi index.html
    Options +ExecCGI +FollowSymlinks
</Directory>
EOF

    ecsudo systemctl enable $service
    ecsudo systemctl start $service
    ecsudo systemctl reload $service	# This should really not be needed

    ecsudo install -d -m 0755 -o ${WUSER} -g ${WGROUP} ${WEBTOP}

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
	    ecsudo install -d -m 0777 -o ${WUSER} -g ${WGROUP} /var/log/stderr
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/stderr(/.*)?"
	    ecsudo install -o ${WUSER} -g ${WGROUP} -m 0666 /var/log/common.log
	    ecsudo semanage fcontext -a -t httpd_log_t "/var/log/common.log"
	    ecsudo restorecon -Rv $WEBTOP
    	fi
    fi

    OVERRIDECONF=/etc/systemd/system/httpd.service.d/override.conf
    if [ -d `dirname $OVERRIDECONF` -a ! -s $OVERRIDECONF ] ; then
        ecsudo install -o root -g root -m 0644 /dev/stdin $OVERRIDECONF <<EOF
[Service]
ProtectSystem=no
ProtectHome=no
EOF
        REBOOT_REASON="$REBOOT_REASON~ProtectSystem disabled in systemd config."
    fi

    echo "[Web software will be installed into ${WEBTOP}]"

    if [ ! -f /etc/cpi_cfg.pl ] ; then
	ecsudo install -o root -g root -m 0644 /dev/stdin /etc/cpi_cfg.pl <<EOF
#\$cpi_vars::WEBOFFSET="YourDomain.com";
#\$cpi_vars::FAX_SERVER="Your fax printer name";
#\$cpi_vars::KEY_CAPTCHA_PUBLIC="Captcha public key";
#\$cpi_vars::KEY_CAPTCHA_PRIVATE="Captcha private key";
\$cpi_vars::WEBOFFSET="$WEBOFFSET";
EOF
    fi
    }

#########################################################################
#	Git clone into a specified directory (managing rootness)	#
#########################################################################
#doc# ### git_clone_to()
#doc# Get project from github and put it in /usr/local/projects.
git_clone_to()
    {
    git_url="$1"
    dest_dir="$2"
    echodo rm -rf $TMP.gct
    echodo mkdir -p $TMP.gct
    ecsudo install -m 0755 -d -o ${USER} -g ${GROUP} $dest_dir
    echocd $TMP.gct
    echodo git clone -q "$git_url"
    echocd *
    echodo cp -r .git * $dest_dir	# Leave the dot files
    }

#########################################################################
#	Install generic project software.				#
#	Note that if no url is provided, we'll see if we can ssh it.	#
#	Otherwise, we'll use the public address.			#
#########################################################################
#doc# ### install_and_configure()
#doc# Populate /usr/local/projects/PROJECT and "make install" in that directory.
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
    ecsudo make install
    }

#########################################################################
#	Bring over the files we need to access github and the rest of	#
#	the world							#
#########################################################################
#doc# ### setup_communication()
#doc# For developer only - grab a script from a local host and run it.
setup_communication()
    {
    ssh 10.1.0.20 sh /usr/local/projects/START_HERE/developer.sh | sh
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
    ecsudo rm -f $SUDO_HACK
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

umask 002

temporarily_disable_sudo_password
trap cleanup EXIT

performa_updates
osinstall git
[ -x /usr/bin/hostname ] || osinstall inetutils
install_and_configure_a_web_server

$BE_CLEAN && ecsudo rm -rf ${WEBTOP} ${PROJECTS_DIR} /etc/cpi_cfg.pl /etc/ssmtp/ssmtp.conf

setup_projects
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

if $LIKE_DEBIAN ; then
    osinstall f2c libncurses-dev
elif $LIKE_REDHAT ; then
    osinstall f2c ncurses-devel
elif $LIKE_ARCH ; then
    mkdir -p $TMP.f2c
    osinstall base-devel
    echocd $TMP.f2c
    echodo git clone https://aur.archlinux.org/f2c.git
    echocd $TMP.f2c/f2c
    yes | echodo makepkg -srif --noprogressbar
    echocd $HOME
fi

install_and_configure multis		# Requires cpi

install_and_configure cci		# Requires common
install_and_configure pandemic		# Requires cpi, common and cci

if $DEVELOPER ; then
    setup_communication
    install_and_configure websh		# Requires cpi & common
fi

if [ -n "$REBOOT_REASON" ] ; then
    echo "REASON TO REBOOT:$REBOOT_REASON" | sed -e 's/~/\n    /g'
fi

exec rm -rf $TMP.*
