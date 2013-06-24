#! /usr/bin/perl 
#
# Given path to nginx log file, rotate it by moving the current one to a new filename.
#
# Set to run as a cronjob at the top of every hour.
# 0 * * * * /path/to/script/scriptname /path/to/log/logfilename /path/to/log/nextfilename
#

use warnings;
use strict;
use File::Basename;
use File::Copy;
use POSIX qw(strftime);

# Send source logfile as an argument such as: $ <scriptname> /var/log/nginx/www.log

my @LOGFILES      = @ARGV;
my $NGINX_PIDFILE = "/var/run/nginx.pid";

my $year_month_date              = strftime "%y-%m-%d", localtime;
my $year_month_date_previoushour = $year_month_date . "." . last_hour();

foreach my $logfile ( @LOGFILES ) { 
    if( ! -w $logfile ) {
	warn "Can't read $logfile, skipping...";
	next;
    }

    if( ! is_move_possible( $logfile ) ) {
	warn "Problem (permissions?) with $logfile";
	next;
    }

    move_logfile( $logfile );
}

send_usr1_to_nginx();

exit 0;

sub is_move_possible {
    my $logfile = shift;

    my( $filename, $dirname ) = fileparse($logfile);

    if( ! -w $dirname ) {
	warn "Can't write to $dirname";
	return 0;
    }
    if( ! -f "$dirname/$filename" ) {
	warn "$dirname/$filename isn't a file.";
	return 0;
    }
    if( ! -w "$dirname/$filename" ) {
	warn "Can't move $dirname/$filename";
	return 0;
    }
    return 1;
}

sub move_logfile {
    my $source_file = shift;

    die "No file given" unless defined( $source_file );

    my $basefilename          = basename("$source_file",".log");
    my( $filename, $dirname ) = fileparse($source_file);

    my $dest_file             = "$dirname$basefilename" . "_" . "$year_month_date_previoushour" . ".log";
    
    # One more sanity check...
    die "Can't read $source_file"               if( ! -r $source_file );
    die "Can't write to " . dirname($dest_file) if( ! -w dirname($dest_file));

    print "Moving $source_file to $dest_file\n";
    move( $source_file, $dest_file ) or warn "Couldn't move $source_file to $dest_file";
}

sub send_usr1_to_nginx {
    my $nginx_pid;
    
    open(FILE, "< $NGINX_PIDFILE") or die "Can't read $NGINX_PIDFILE";
    $nginx_pid = <FILE>;
    close(FILE);
    
    die "nginx isn't running (PID in $NGINX_PIDFILE) or insufficient permissions" if( ! kill 0, $nginx_pid );
    
    kill "USR1", $nginx_pid or warn "Couldn't send kill USR1 to $nginx_pid";
}

sub last_hour {
    # stolen from http://osdir.com/ml/lang.perl.beginners/2002-07/msg01795.html
    my $hour = shift;
    $hour = (localtime)[2] unless defined $hour;
    $hour--;
    $hour += 24 if $hour < 0;
    return sprintf("%02d", $hour);
}
