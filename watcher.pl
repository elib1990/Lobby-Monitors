#!/usr/bin/perl -w
# Watchdog to reboot the machine if file appears
$|++;
my $status;

while(1)
{
    if (-e "/var/log/slides/re.txt")
    {
	`/bin/rm -rf /var/log/slides/re.txt`;
	print "echo eweblobby | sudo reboot now\n";
	`echo "eweblobby" | sudo -S reboot now`;
    }
    $status = 0;
    for (split '\n', `ps alx`)
    {
        if (/perl.*slides.sh/)
	{
	    $status = 1;
	}
    }
    if ($status) { print "All is well\n"; }
    else
    {
	print "Need to restart slideshow\n";
	sleep(30);
	system("/usr/bin/perl /home/lobby/Downloads/slides.sh &");
	print "Should be restarting now\n";
    }
    sleep(10);
}
