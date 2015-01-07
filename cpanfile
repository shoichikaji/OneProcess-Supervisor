requires 'perl', '5.008001';
requires "Daemon::Control";
requires "Process::Status";
requires "Class::Accessor::Lite";

on 'test' => sub {
    requires 'Test::More', '0.98';
};

