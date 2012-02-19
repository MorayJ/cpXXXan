#!/usr/local/bin/perl

use strict;
use warnings;
use Parallel::ForkManager;

my $build_script = shift(@ARGV);

my $par = Parallel::ForkManager->new(2);

print "start: ".localtime()."\n";
my $start = time();
foreach my $arg (@ARGV) {
  $par->start() && next;

  my $output = "$arg: ".localtime()." - ";
  my $start = time();
  system("$build_script $arg");
  print "  $output".localtime()."; secs: ".sprintf("%.2f", time() - $start)."\n";
  $par->finish();
}
$par->wait_all_children();

print "finish:  ".localtime()."\n";
print "elapsed: ".sprintf("%.2f mins == %d secs\n", (time() - $start)/60, time() - $start);
