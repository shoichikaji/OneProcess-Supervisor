#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use utf8;
use OneProcess::Supervisor::CLI;
OneProcess::Supervisor::CLI->new->parse_options(@ARGV)->run;

__END__

=head1 NAME

supervisor.pl - supervisor for 1 process

=head1 SYNOPSIS

    > supervisor.pl [OPTIONS] COMMANDS

    Options:
    -l, --log FILE    log file
    -d, --daemonize   daemonize mode
    -p, --pid FILE    pid file for daemonize mode
    -h, --help        show this help

    Example:
    > supervisor.pl ruby long-time-script.rb
    > supervisor.pl --log your.log ruby long-time-script.rb
    > supervisor.pl -d -p /tmp/hoge.pid -l foo.log "cat foo | xargs -P10 perl foo.pl"

=cut

