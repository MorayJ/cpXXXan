#!/usr/local/bin/perl

use strict;
use warnings;
use Parallel::ForkManager;
use DBM::Deep;

my $build_script = shift(@ARGV);

my $par = Parallel::ForkManager->new(2);
my $db  = DBM::Deep->new(
    file => "/tmp/parallel-builder-history.db",
);

# order jobs by how long they took last time (assuming 0
# seconds if not seen before), longest first
my @jobs = sort {
    (exists($db->{$b}) ? $db->{$b} : 0) <=>
    (exists($db->{$a}) ? $db->{$a} : 0)
} map { s/'//g; $_ } @ARGV;

print "start: ".localtime()."\n";
my $start = time();
foreach my $job (@jobs) {
  $par->start() && next;

  my $output = "$job: ".localtime()." - ";
  my $start = time();
  system("$build_script $job");
  $db->{$job} = time() - $start;
  print "  $output".localtime()."; secs: ".$db->{$job}."\n";
  $par->finish();
}
$par->wait_all_children();

print "finish:  ".localtime()."\n";
print "elapsed: ".sprintf("%.2f mins == %d secs\n", (time() - $start)/60, time() - $start);
