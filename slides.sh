#!/usr/bin/perl -w
# Create identities for separate instances of the slideshow program
#    mkdir /tmp/<NAME>
#    export HOME="/home/<NAME>"
#    soffice <NAME>.pps  (set up auto/0sec in "Slideshow settings")
#
use POSIX ();
use FindBin ();
use File::Basename;
use File::Spec::Functions;

  # make the daemon cross-platform, so exec always calls the script
  # itself with the right path, no matter how the script was invoked.
  my $script = File::Basename::basename($0);
  my $SELF = catfile $FindBin::Bin, $script;

$|++;

# my ($zero, $one) = (":0.0", ":0.0");  # Xinerama, etc. Elapse(laptop)
#  my ($zero, $one) = (":0.0", ":0.1");  # Separate X11 Displays (Lobby)

my $env = "export HOME=/home/";            # Separate identities
#my $dis = "export DISPLAY=";               # Separate identities
#my $opt = "-nolockcheck -minimized -nologo -show "; # Options;
my $opt = "-show "; #libreoffice option
my $office = "libreoffice";          # OR "openoffice.org"

my @suffix = qw(.odp .ppt .pps );

my ($n1, $n2) = ("bigscreen","littlescreen"); # Slideshow names

# Determinte the suffix (file types) of the current slideshows
my ($cursuf1, $cursuf2) = ( $suffix[0], $suffix[0] ); # DEFAULT
for my $suf (@suffix) {
    if (-e "/home/$n2/$n2$suf") { $cursuf2 = $suf; }
    if (-e "/home/$n1/$n1$suf") { $cursuf1 = $suf; }
}

print "Current suffixes are big $cursuf1 and little $cursuf2\n";

#
# Some settings depending upon the display configuration.
#
# Be sure to clean up (remove lock files) etc. at exit

$SIG{INT} = sub { cleanup(); exit(0); };

# Make a backup registry file for each identity if it doesn't exist

  for (($n2, $n1))
  {
    if (!-e "/home/$_/.$office/3/user/registry.save")
    {
      `cp /home/$_/.$office/3/user/registrymodifications.xcu /home/$_/.$office/3/user/registry.save`
    }
  }


while(1)
{
    if ( scan() )  # True when slide shows need restarting
    {
	cleanup();
	#system("$env$n1 ; $dis$zero ; soffice $opt /home/$n1/$n1$cursuf1 &");
	#system("$env$n2 ; $dis$one ; soffice $opt /home/$n2/$n2$cursuf2 &");
        system("$env$n2 ; $office $opt /home/$n2/$n2$cursuf2 &");
        system("$env$n1 ; $office $opt /home/$n1/$n1$cursuf1 &");
    }
    sleep(20);
    checkTime();
}

# scan() also checks to make sure all soffice programs are running.
# When a new presentation file become available:
#
# 1) Copy the new file(s)
#
# 2a) Rename it on the flash drive and copy previous onto flash drive
#            -OR-
# 2b) Remove the file from the Web upload directory
#
# 3) return 1 to indicate that the slideshows need restarting.
#
# 4) Keep track of the suffix of the new file (it becomes the default).
#

sub scan
{
my $changed = 0;

for my $suf (@suffix) {

 for my $dir (</media/*>) {

     my $edir = $dir;
     $edir =~ s/ /\\ /g;

    if (-e "$dir\/bigscreen$suf")
    {
	print "I see a big slide show on $dir\n";

	`cp /home/bigscreen/bigscreen.* $edir\/bigscreen.prev`;

	`rm -rf /home/bigscreen/bigscreen.*`;
#	print "backup the current slideshow to the flash drive\n";
	`cp $edir\/bigscreen$suf /home/bigscreen/`;
#	print "copied it over\n";
	$changed = 1;
        $cursuf1 = $suf;
	`mv $edir\/bigscreen$suf $edir\/bigscreen.uploaded`;
#	print "changed its name on the flash driver\n";
#	`umount $edir`;
    } else  {
#	print "[$dir\/bigscreen$suf] doesn't exist!";
    }
    if (-e "$dir\/littlescreen$suf") {
	print "I see a little slide show on $dir\n";
	`cp /home/littlescreen/littlescreen.* $edir\/littlescreen.prev`;
	`rm -rf /home/littlescreen/littlescreen.*`;
#	print "backup the current slideshow to the flash drive\n";
	`cp $edir\/littlescreen$suf /home/littlescreen/`;
#	print "copied it over\n";
	$changed = 1;
        $cursuf2 = $suf;
	`mv $edir\/littlescreen$suf $edir\/littlescreen.uploaded`;
#	print "changed its name on the flash driver\n";
#	`umount $edir`;
    } else {
#	print "[$dir\/littlescreen$suf] doesn't exist!";
    }

  } # FOR EACH INSTANCE OF REMOVABLE MEDIA (cdrom, usb drive, etc.)


   # CHECK WEB UPLOAD AREA FOR NEW FILES
     for (($n1, $n2))
     {
	 if (-e "/var/www/uploads/$_$suf")
	 {
	     if (moveSafely("/var/www/uploads/$_$suf","/home/$_/$_$suf"))
	     {
		 $changed = 1;
		 if ($_ eq $n1) { $cursuf1 = $suf; }
		 if ($_ eq $n2) { $cursuf2 = $suf; }
		 print "copied it over\n";
	     }
	 }
     } # END CHECK WEB UPLOAD AREA FOR NEW FILES

 }  # FOR EACH POSSIBLE TYPE OF SLIDESHOW: .odp .pps .ppt  etc.

 my @prs = split('\n',`ps ax`);
 my $count = 0;
 for (@prs)
 {
     if ( /soffice\.bin/ ) { $count++; }
 }
 if ($count != 2) {
	sleep(60);
        $changed = 1;
}
 return $changed;
}

sub moveSafely
{
    my ($src,$dest) = @_;
    my ($base, undef, undef) = fileparse($src, qr/\.[^.]*/);

    if (-e $src)
    {
	`rm -rf $dest`;                 # CLEAR OUT THE OLD
	`cp $src $dest`;            # COPY NEW
	`rm -rf /var/www/files/$base.*`;  # Remove previous
	`cp $src /var/www/files/`;  # REFERENCE COPY
	if (-e $dest)     # RM UPLOADED AFTER COPY
	{
	    webpage($src); # Update Web Interface Link
	    `rm -rf $src`;
	    return 1;
	} else {
	    print "FAILED TO COPY [$src] TO [$dest]\n";
	}
    } else {
	print "FAILED COPY [$src] TO [$dest]: $src does not exist.\n";
    }
    return 0;
}

sub webpage
{
 my ($file) = shift;
 my ($base, $path, $suf) = fileparse($file, qr/\.[^.]*/);
 open WHERE, ">/var/www/files/$base.html";
 print WHERE <<LINKSTUFF;
<html><body>
<h1><a href="/files/$base$suf">$base$suf</a></h1>
</body></html>
LINKSTUFF

 close WHERE;
}

sub cleanup  # Kill Libre/Open Office processes and remove lock files
{
    `killall -e soffice.bin 2>&1`;
    `rm -rf .~lock*`;
    for (($n2,$n1))
    {
	`rm -rf /home/$_/.~lock*`;
	`rm -rf /home/$_/.$office/3/.lock*`;
	if (-e "/home/$_/.$office/3/user/registry.save")
	{
	    `rm -rf /home/$_/.$office/3/user/registrymodifications.xcu`;
	    `cp  /home/$_/.$office/3/user/registry.save /home/$_/.$office/3/user/registrymodifications.xcu`;
#	    print "Copied registry backup file\n";
	}
    }
}

# Restart just before midnight every night (to avoid memory leaks).

sub checkTime
{
    my $late = `date +%H%M`;
    if ( $late =~ /^2358/ )
    {
             print "Restarting at midnight\n";
             cleanup();
	     sleep(60);
             exec($SELF, @ARGV);
    }
}
