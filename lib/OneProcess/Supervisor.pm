package OneProcess::Supervisor;
use 5.008005;
use strict;
use warnings;
use strict;
use Daemon::Control;
use IO::Handle;
use IO::Select;
use Process::Status;
use POSIX qw(strftime);
use Class::Accessor::Lite rw => [qw(
    command fh select child_stdout child_stderr
    daemonize pid signal_recieved
)];

our $VERSION = "0.01";
use constant DEBUG => $ENV{SUPERVISOR_DEBUG};

sub new {
    my ($class, %option) = @_;
    my $command = delete $option{command} or die;
    my $fh = $option{fh} || \*STDOUT;
    bless {
        %option,
        command => $command,
        fh => $fh,
        select => IO::Select->new,
        child_stdout => undef,
        child_stderr => undef,
    }, $class;
}
sub generate_pipe {
    my $self = shift;
    pipe my $in0, my $out0;
    pipe my $in1, my $out1;
    pipe my $in2, my $out2;
    $_->autoflush(1) for $out1, $out2;
    {
        ctl => { in => $in0, out => $out0 },
        out => { in => $in1, out => $out1 },
        err => { in => $in2, out => $out2 },
    };
}
sub child_read {
    my $self = shift;
    my $LEN;
    if (my @ready = $self->select->can_read(0.1)) {
        for my $ready (@ready) {
            my $type = $ready == $self->child_stdout ? "out" : "err";
            my $len = sysread $ready, my $buffer, 1024;
            if (!defined $len) {
                $self->say(cmd => "sysread child std${type} failed: $!");
                $self->select->remove($ready);
            } elsif ($len == 0) {
                $LEN += 0;
                $self->select->remove($ready);
            } else {
                $self->say($type => $_) for split /\r?\n/, $buffer;
                $LEN += $len;
            }
        }
    }
    return $LEN;
}
sub run {
    my $self = shift;
    open STDIN, "</dev/null";

    $SIG{TERM} = sub {
        $self->signal_recieved(1);
        $self->say(cmd => "parent catch SIGTERM");
    };
    while (1) {
        my $exit = $self->do_fork;
        exit 255 unless defined $exit;
        $self->say(cmd => "child @{[ $exit->as_string ]}");
        last if $exit->is_success;
        last if $self->signal_recieved;
    }

}
sub say {
    my ($self, $type, $message) = @_;
    $self->fh->say( "[@{[ strftime('%F %T', localtime) ]}][$type] $message" );
}

sub do_fork {
    my $self = shift;

    my $pipe = $self->generate_pipe;
    my $child_exit; $SIG{CHLD} = sub { $child_exit++ };
    my $pid = fork;
    if (!defined $pid) {
        $self->say(cmd => "Internal error, fork failed: $!");
        exit 255;
    }

    if ($pid == 0) {
        $SIG{CHLD} = "DEFAULT";
        $SIG{TERM} = "DEFAULT";
        close $pipe->{out}{in};
        close $pipe->{err}{in};
        close $pipe->{ctl}{in};
        open STDOUT, ">&=", fileno($pipe->{out}{out}) or die;
        open STDERR, ">&=", fileno($pipe->{err}{out}) or die;
        eval { exec @{ $self->command } };
        $pipe->{ctl}{out}->say(sprintf "child exec '%s' failed: %s",
            "@{ $self->command }", $@ || $! );
        exit 255;
    }
    close $pipe->{out}{out};
    close $pipe->{err}{out};
    close $pipe->{ctl}{out};

    $self->say(cmd => "forking new child $pid");
    if (my $failed_message = do { local $/; $pipe->{ctl}{in}->getline }) {
        chomp $failed_message;
        $self->say(cmd => $failed_message);
        return undef;
    }
    $self->child_stdout($pipe->{out}{in});
    $self->child_stderr($pipe->{err}{in});
    $self->select->add($pipe->{out}{in}, $pipe->{err}{in});

    while (!$self->signal_recieved && !$child_exit && $self->select->handles) {
        my $read_length = $self->child_read;
    }
    $self->child_read unless $self->signal_recieved;
    close $_ for $self->child_stdout, $self->child_stderr;
    if ($self->signal_recieved) {
        my $c = kill TERM => $pid;
        my $result = $c ? "success" : "fail";
        $self->say(cmd => "sending SIGTERM to child $pid ... $result");
    }
    my $r = waitpid $pid, 0;
    my $exit = Process::Status->new($?);
    return $exit;
}

sub daemonize_run {
    my $self = shift;
    Daemon::Control->new(
        name => $0,
        program => sub { $self->run },
        pid_file => $self->pid || "supervisor.pid",
        stderr_file => "/dev/null",
        stdout_file => "/dev/null",
        fork => 2,
    )->do_start;
}


1;
__END__

=encoding utf-8

=head1 NAME

OneProcess::Supervisor - supervisor for 1 process

=head1 SYNOPSIS

    > supervisor.pl --daemonize --pid foo.pid --log foo.log ruby long-time-script.rb

=head1 DESCRIPTION

OneProcess::Supervisor is a simple supervisor for 1 process management.

=head1 LICENSE

Copyright (C) Shoichi Kaji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Shoichi Kaji E<lt>skaji@cpan.orgE<gt>

=cut

