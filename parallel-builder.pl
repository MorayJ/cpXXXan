#!/usr/local/bin/perl

use strict;
use warnings;
use Parallel::ForkManager;
use DBM::Deep;
use IPC::ConcurrencyLimit;

my $limit = concurrency_limit("/tmp/parallel-builder.lock");

my $build_script = shift(@ARGV);

my $par = Parallel::ForkManager->new(2, '/tmp');
my $db_dbm  = DBM::Deep->new(
    file => "/tmp/parallel-builder-history.db",
);

# clone into memory to avoid fork()y hatefulness
my $db = { map { $_ => $db_dbm->{$_} } keys %{$db_dbm} };

undef $db_dbm;

# order jobs by how long they took last time (assuming 0
# seconds if not seen before), longest first
my @jobs = sort {
    (exists($db->{$b}) ? $db->{$b} : 0) <=>
    (exists($db->{$a}) ? $db->{$a} : 0)
} map { s/'//g; $_ } @ARGV;

# print "start: ".localtime()."\n";
my $start = time();

$par->run_on_finish(sub {
    my(undef, undef, undef, undef, undef, $data) = @_;
    $db->{$data->{job}} = $data->{elapsed};
});

foreach my $job (@jobs) {
  $par->start() && next;

  my $output = "$job: ".localtime()." - ";
  my $start = time();
  system("$build_script $job");
  my $elapsed = time() - $start;
  # print "  $output".localtime()."; secs: $elapsed\n";
  $par->finish(0, { job => $job, elapsed => $elapsed });
}
$par->wait_all_children();

# print "finish:  ".localtime()."\n";
# print "elapsed: ".sprintf("%.2f mins == %d secs\n", (time() - $start)/60, time() - $start);

$db_dbm  = DBM::Deep->new(
    file => "/tmp/parallel-builder-history.db",
);
$db_dbm->{$_} = $db->{$_} foreach (keys%{$db});

sub concurrency_limit {
    my $lockfile = shift;
    my $limit = IPC::ConcurrencyLimit->new(
        max_procs => 1,
        path      => $lockfile,
    );
    my $limitid = $limit->get_lock;
    if(not $limitid) {
        warn "Another process appears to be still running. Exiting.";
        exit(0);
    }
    return $limit;
}
