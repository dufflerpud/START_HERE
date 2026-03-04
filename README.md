# Documentation for START_HERE

Software to document the dufflerpud project generally and install it all.

If you're feeling trusting, get onto a new machine, cd to your home directory
and type:
<li>curl https://raw.githubusercontent.com/dufflerpud/START_HERE/refs/heads/main/START_HERE.sh > START_HERE.sh
<li>sh START_HERE.sh

<hr>

<table src="*.sh"><tr><th align=left><a href='#dt_87LLIVxAM'>Install_and_Build.sh</a></th><td>A script to download and install all of the dufflerpud projects</td></tr>
<tr><th align=left><a href='#dt_87LLIVxAN'>START_HERE.sh</a></th><td>A script to grab the Install_and_Build script and run it</td></tr></table>

<hr>

<div id=docs>

## <a id='dt_87LLIVxAM'>Install_and_Build.sh</a>
A script to download and install all of the dufflerpud projects

## <a id='dt_87LLIVxAN'>START_HERE.sh</a>
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


