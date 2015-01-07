use strict;
use warnings;
use utf8;
use Test::More;

sub run {
    my $exit = system $^X, "-Ilib", "--", "script/supervisor.pl", @_;
    $exit << 8;
}

is run(qw(-- perl -v)), 0;
ok run(qw(-- zzzzzzz)) != 0;


done_testing;
