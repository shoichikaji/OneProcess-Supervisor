use strict;
use Test::More 0.98;

use_ok $_ for qw(
    OneProcess::Supervisor
    OneProcess::Supervisor::CLI
);

ok system($^X, "-wc", "script/supervisor.pl") == 0;

done_testing;

