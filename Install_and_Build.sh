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

PROG=`basename $0`
USER=`id -un`
GROUP=`id -gn`
WUSER=www-data
WGROUP=www-data
WEBTOP=/var/www/html/sto

FS0_IP=10.1.0.20
FS0_NAME=fs0
SSHFILES=chris@${FS0_IP}:.ssh/github.com
REF_FILES=chris@${FS0_IP}:vm_stuff/ref.cpio
SSHDIR=/home/$USER/.ssh

PROJECTS_DIR=/usr/local/projects
BE_CLEAN=false

#########################################################################
#	Echo command and then do it.					#
#########################################################################
echodo()
    {
    echo "+ $@" >&2
    "$@"
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
    ecsudo apt update -yq
    ecsudo apt upgrade -yq
    }

#########################################################################
#	Setup to start working in PROJECTS_DIR				#
#########################################################################
setup_projects()
    {
    echo "[ Setting up projects ]"
    ecsudo apt install -qqy make gcc translate-shell libjpeg-dev
    ecsudo apt install -qqv sox ghostscript netpbm poppler-utils
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
    ecsudo apt install -qqy apache2
    #tmog l - - - /etc/apache2/mods-enabled/cgi.load ../mods-available/cgi.load
    [ -h /etc/apache2/mods-enabled/cgi.load ] || \
	ecsudo ln -s ../mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load
    #tmog l - - - /etc/apache2/conf-enabled/serve-cgi-bin.conf ../conf-available/serve-cgi-bin.conf
    [ -h /etc/apache2/conf-enabled/serve-cgi-bin.conf ] || \
	ecsudo ln -s ../conf-available/serve-cgi-bin.conf /etc/apache2/conf-enabled/serve-cgi-bin.conf
    ecsudo install -d -m 0755 -o ${WUSER} -g ${WGROUP} ${WEBTOP}
    ecsudo ed -s /etc/apache2/apache2.conf <<EDEOF
	/<Directory \/var\/www\/
	a
	AddHandler cgi-script .cgi .pl
.
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
#########################################################################
install_and_configure()
    {
    project="$1"
    url=${2:-"https://github.com/dufflerpud/$project.git"}
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
    echo "[ Setting up communication ]"
    githubdir="$SSHDIR/github.com"
    echodo rm -rf $githubdir
    echodo mkdir -p $githubdir
    echodo scp -q "$SSHFILES/*-ro" $githubdir
    echodo cd $githubdir
    for sshkeyfile in * ; do
	githubhost="github.com-$sshkeyfile"
	echo "host $githubhost"
	echo "    Hostname github.com"
	echo "    User git"
	echo "    IdentityFile $githubdir/$sshkeyfile"
	echo "    IdentitiesOnly yes"
    done > $SSHDIR/config
    echodo chmod -R go-rwx $SSHDIR/config $githubdir

    if grep -s $FS0_NAME /etc/hosts >/dev/null; then
	echo "/etc/hosts already updated."
    else
	echodo scp -q ${FS0_IP}:/etc/hosts /tmp/hosts.0
	echodo grep -v '^127' < /tmp/hosts.0 > /tmp/hosts.1
	ecsudo dd if=/tmp/hosts.1 of=/etc/hosts oflag=append conv=notrunc
    fi
    }

#########################################################################
#	E-mail configuration						#
#########################################################################
install_and_configure_email()
    {
    tmp=/tmp/$PROG
    echo "[ Setting up e-mail ]"
    ecsudo apt install -qqy ssmtp mailutils
    echodo scp $REF_FILES $tmp
    echocd /
    ecsudo cpio -iduv < $tmp
    ecsudo chown root:root `cpio -it < $tmp
    ecsudo chmod 644 `cpio -it < $tmp
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
#	Main								#
#########################################################################

while [ "$#" -gt 0 ] ; do
    case "$1" in
	-clean)	BE_CLEAN=true					;;
	*)	PROBLEMS="${PROBLEMS}Unknown argument [$1]~"	;;
    esac
    shift
done

[ -z "$PROBLEMS" ] || usage "$PROBLEMS"

$BE_CLEAN && ecsudo rm -rf ${WEBTOP} ${PROJECTS_DIR} /etc/cpi_cfg.pl /etc/ssmtp/ssmtp.conf

performa_updates
install_and_configure_apache2_web_server

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
install_and_configure websh		# Requires cpi & common
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

ecsudo apt -qqy install f2c libncurses-dev
install_and_configure multis		# Requires cpi

install_and_configure cci		# Requires common
install_and_configure pandemic		# Requires cpi, common and cci

#setup_communication
#install_and_configure_email
