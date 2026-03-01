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
WUSER=`awk -F: '/^(apache|www-data)/ {print $3}' /etc/passwd`
WGROUP=`awk -F: '/^(apache|www-data)/ {print $4}' /etc/passwd`

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

#########################################################################
#	Echo command and then do it.					#
#########################################################################
echodo()
    {
    echo "+ $@" >&2
    "$@"
    }

#########################################################################
#	Turn off sudo asking passwords for the duration of the script.	#
#	There is a special place in hell for me.  I know it.		#
#########################################################################
make_sudo_friendly()
    {
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' | \
	sudo install -o root -g root -m 0444 /dev/stdin $SUDO_HACK
    }

#########################################################################
#	Echo command and then do it AS ROOT.				#
#	Note that "ecsudo cd ..." will not do anything useful since the	#
#	shell with that updated CWD will immediately exit.		#
#########################################################################
ecsudo()
    {
    echo "! $@" >&2
    sudo "$@"
    }

#########################################################################
#	Change directory (whether root or not)				#
#########################################################################
echocd()
    {
    echo "[ Changing directory to $1 ]"
    #echodo cd "$1"
    cd "$1"
    }

#########################################################################
#	Make sure we're working on an uptodate system.			#
#########################################################################
performa_updates()
    {
    echo "[ Performa updates ]"
    if [ -x /bin/dnf ] ; then
        ecsudo dnf -y update
    elif [ -x /bin/apt ] ; then
	ecsudo apt update -yq
	ecsudo apt upgrade -yq
    else
        echo "Unable to update this OS, continuing."
    fi
    }

#########################################################################
#	Use the right installation tool					#
#########################################################################
osinstall()
    {
    if [ -x /bin/dnf ] ; then
        ecsudo dnf -y install $*
    elif [ -x /bin/apt ] ; then
        ecsudo apt install -qqy $*
    else
        echo "Unable to install:  " $*
	exit 1
    fi
    }

#########################################################################
#	Setup to start working in PROJECTS_DIR				#
#########################################################################
setup_projects()
    {
    echo "[ Setting up projects ]"
    osinstall script make gcc translate-shell
    osinstall sox ghostscript netpbm poppler-utils cpan
    $LIKE_DEBIAN && osinstall libjpeg-dev
    if [ ! -e /usr/lib/sendmail ] ; then
	osinstall ssmtp
	$LIKE_DEBIAN && osinstall mailutils
    fi
    ecsudo PERL_MM_USE_DEFAULT=1 cpan -i CPAN
    ecsudo cpan install -i Imager/File/JPEG.pm
    ecsudo install -d -m 0755 -o root -g root ${PROJECTS_DIR}
    }

#########################################################################
#	Install and configure the Apache2 web server			#
#	Pretty ubuntu dependent.					#
#########################################################################
install_and_configure_apache2_web_server()
    {
    echo "[ Installing and configuring Apache web server ]"
    osinstall apache2
    #tmog l - - - /etc/apache2/mods-enabled/cgi.load ../mods-available/cgi.load
    [ -h /etc/apache2/mods-enabled/cgi.load ] || \
	ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
    #tmog l - - - /etc/apache2/conf-enabled/serve-cgi-bin.conf ../conf-available/serve-cgi-bin.conf
    [ -h /etc/apache2/conf-enabled/serve-cgi-bin.conf ] || \
	ecsudo ln -s ../conf-available/serve-cgi-bin.conf /etc/apache2/conf-enabled/serve-cgi-bin.conf
    grep 'AddHandler cgi-script' /etc/apache2/apache2.conf > /dev/null || ecsudo ed -s /etc/apache2/apache2.conf <<EDEOF
	/<Directory \/var\/www\/
	a
	AddHandler cgi-script .cgi .pl
.
	w
	q
EDEOF
    grep 'Options ExecCGI' /etc/apache2/apache2.conf > /dev/null || ecsudo ed -s /etc/apache2/apache2.conf <<EDEOF
	/<Directory \/var\/www\/
	/Options
	s/Options/Options ExecCGI/
	w
	q
EDEOF
    ecsudo systemctl enable apache2
    ecsudo systemctl start apache2
    ecsudo systemctl reload apache2	# This should really not be needed
    }

#########################################################################
#	Install and configure the httpd web server			#
#	Pretty Redhat dependent.					#
#########################################################################
install_and_configure_httpd_web_server()
    {
    echo "[ Installing and configuring httpd web server ]"
    osinstall httpd
    if grep 'AddHandler cgi-script' /etc/httpd/conf.d/cgi.conf > /dev/null 2>&1 ; then
	:
    else
        echo "AddHandler cgi-script .cgi .pl" | \
	    ecsudo dd of=/etc/httpd/conf.d/cgi.conf oflag=append
    fi
    grep 'Options .*ExecCGI' /etc/httpd/conf/httpd.conf > /dev/null 2>&1 || \
	ecsudo ed -s /etc/httpd/conf/httpd.conf <<EDEOF
	/<Directory "\/var\/www\/
	/Options
	s/Options/Options +ExecCGI/
	w
	q
EDEOF
    ecsudo systemctl enable httpd.service
    ecsudo systemctl start httpd.service
    ecsudo systemctl reload httpd.service	# This should really not be needed
    }

#########################################################################
#	Decide what web server is appropriate and get it going.		#
#########################################################################
install_and_configure_a_web_server()
    {
    if $LIKE_REDHAT ; then
	install_and_configure_httpd_web_server
    else
	install_and_configure_apache2_web_server
    fi
    for DOCUMENTROOT in /var/www/www /var/www/html ; do
	if [ -d $DOCUMENTROOT ] ; then
	    WEBTOP=$DOCUMENTROOT$WEBOFFSET
	    break
	fi
    done

    if [ -z "$WEBTOP" ] ; then
	echo "No documentroot found."
	exit 1
    fi

    if [ ! -f /etc/cpi_cfg.pl ] ; then
	tmpfile=/tmp/$PROG.$$
        sed -e 's/^	*//' > $tmpfile <<EOF
		#\$cpi_vars::WEBOFFSET="YourDomain.com";
		#\$cpi_vars::FAX_SERVER="Your fax printer name";
		#\$cpi_vars::KEY_CAPTCHA_PUBLIC="Captcha public key";
		#\$cpi_vars::KEY_CAPTCHA_PRIVATE="Captcha private key";
		\$cpi_vars::WEBOFFSET="$WEBOFFSET";
EOF
	ecsudo install -o root -g root -m 0644 $tmpfile /etc/cpi_cfg.pl
	rm $tmpfile
    fi

    ecsudo install -d -m 0755 -o ${WUSER} -g ${WGROUP} ${WEBTOP}
    ecsudo firewall-cmd --zone=public --add-service=http --permanent
    ecsudo systemctl reload firewalld.service
    echo "[Web software will be installed into ${WEBTOP}]"
    }

#########################################################################
#	Git clone into a specified directory (managing rootness)	#
#########################################################################
git_clone_to()
    {
    tmp=/tmp/git_clone_to
    git_url="$1"
    dest_dir="$2"
    echodo mkdir -p $tmp
    ecsudo install -m 0755 -d -o ${USER} -g ${GROUP} $dest_dir
    echocd $tmp
    echodo git clone -q "$git_url"
    echocd *
    echodo cp -r .git * $dest_dir	# Leave the dot files
    echodo rm -rf $tmp
    }

#########################################################################
#	Install generic project software.				#
#	Note that if no url is provided, we'll see if we can ssh it.	#
#	Otherwise, we'll use the public address.			#
#########################################################################
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
setup_communication()
    {
    ssh 10.1.0.20 sh /usr/local/projects/START_HERE/developer.sh | sh
    }

#########################################################################
#	Print an error message and die.					#
#########################################################################
fatal()
    {
    echo "$*" >&2
    exit 1
    }

#########################################################################
#	Print a USEFUL error message ... and die.			#
#########################################################################
usage()
    {
    echo "$*" | tr ~ '\n' >&2
    fatal "Usage:  $PROG [-clean]"
    }

#########################################################################
#	Get rid of the travesty we created for doing things as root.	#
#########################################################################
cleanup()
    {
    ecsudo rm -f $SUDO_HACK
    }

#########################################################################
#	Main								#
#########################################################################

while [ "$#" -gt 0 ] ; do
    case "$1" in
	-c*)	BE_CLEAN=true					;;
	-d*)	DEVELOPER=true					;;
	-w*)	WEBOFFSET="$2"; shift				;;
	*)	PROBLEMS="${PROBLEMS}Unknown argument [$1]~"	;;
    esac
    shift
done

[ -z "$PROBLEMS" ] || usage "$PROBLEMS"

make_sudo_friendly
trap cleanup EXIT

performa_updates
osinstall git
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

osinstall f2c
$LIKE_DEBIAN && osinstall libncurses-dev
$LIKE_REDHAT && osinstall ncurses-devel
install_and_configure multis		# Requires cpi

install_and_configure cci		# Requires common
install_and_configure pandemic		# Requires cpi, common and cci

if $DEVELOPER ; then
    setup_communication
    install_and_configure websh		# Requires cpi & common
fi
