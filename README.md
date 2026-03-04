# Documentation for START_HERE

Software to document the dufflerpud project generally and install it all.

If you're feeling trusting, get onto a new machine, cd to your home directory
and type:
<li>curl https://raw.githubusercontent.com/dufflerpud/START_HERE/refs/heads/main/START_HERE.sh > START_HERE.sh
<li>sh START_HERE.sh

<hr>

<table src="*.sh"><tr><th align=left><a href='#dt_87LMlc6J2'>Install_and_Build.sh</a></th><td>A script to download and install all of the dufflerpud projects</td></tr>
<tr><th align=left><a href='#dt_87LMlc6J3'>START_HERE.sh</a></th><td>A script to grab the Install_and_Build script and run it</td></tr></table>

<hr>

<div id=docs>

## <a id='dt_87LMlc6J2'>Install_and_Build.sh</a>
A script to download and install all of the dufflerpud projects
##echodo()
Print a command and execute it
##make_sudo_friendly()
Since this script can take a while (due to update, installing CPAN modules),
temporarily update sudo configuration to not require passwords every 5 minutes.
##ecsudo()
Print a command and execute it via sudo
##echocd()
Note that we're changing directory and do it.
##performa_updates()
Do whatever os requires to be reasonably up to date
##osinstall()
Figure out what tool is used to install and install specified packages
##setup_projects()
Setup directory structure for all the different cpi projects.
This will include installing make, gcc etc.
##install_and_configure_a_web_server()
Figure out correct web server to install, configure that server and make sure it
it can be accessed if there is a local firewall.
##git_clone_to()
Get project from github and put it in /usr/local/projects.
##install_and_configure()
Populate /usr/local/projects/PROJECT and "make install" in that directory.
##setup_communication()
grab a script from a local host and run it.
##fatal()
Print an error message and exit.
##usage()
Print a useful error message and die.
##cleanup()
Remove any temporary files and sudo hack to allow normal sudo behavior

## <a id='dt_87LMlc6J3'>START_HERE.sh</a>
A script to grab the Install_and_Build script and run it
Don't over think this.  You WILL PROBABLY decide to just get the
Install_and_Build script by hand and run it yourself.  This is
as complex as it is only to help debug the installer.  By the time
you are working with it, we hope the installer already works.
So just run it and ignore this.

Installs script only for debugging purposes.

Installs git because the majority of time, we get the installer
right off github.com.  Installer will also make sure git gets installed
because sometimes it gets here otherwise.  Assume as little as possible.</div>

<hr>

If you add a file with #doc#/#indx# lines, you should make sure it will be
found in the 'table src=' line above and then rerun doc_sep in this directory.

Similarly, if you remove files, re-run doc_sep.



