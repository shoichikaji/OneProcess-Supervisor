package OneProcess::Supervisor::CLI;
use strict;
use warnings;
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case bundling);
use Pod::Usage 'pod2usage';
use OneProcess::Supervisor;

sub new { bless {}, shift }
sub parse_options {
    my ($self, @argv) = @_;
    local @ARGV = @argv;
    GetOptions
        "h|help" => sub { pod2usage(0) },
        "d|daemonize" => \$self->{daemonize},
        "p|pid=s"     => \$self->{pid},
        "l|log=s"       => \$self->{log},
    or pod2usage(1);

    $self->{command} = \@ARGV;
    $self;
};
sub run {
    my $self = shift;
    my $fh;
    if ($self->{log}) {
        open $fh, ">>", $self->{log} or die "open $self->{log}: $!";
    }
    my $s = OneProcess::Supervisor->new(
        pid => $self->{pid},
        fh => $fh,
        command => $self->{command},
    );

    $self->{daemonize} ? $s->daemonize_run : $s->run;
}
1;
