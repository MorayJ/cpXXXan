#!/usr/local/bin/perl

use warnings;
use strict;

use DBI;

$| = 1;

my $verbose = (@ARGV && shift() eq '-v') ? 1 : 0;

# Configuration for DRC's laptop and for live
use constant BACKPAN => -e '/web/cpxxxan/backpan'
    ? '/web/cpxxxan/backpan'
    : '/Users/david/BackPAN';
use constant CPXXXANROOT => -e '/web/cpxxxan'
    ? '/web/cpxxxan'
    : '.';

my $cpxxxan = DBI->connect('dbi:mysql:database=cpXXXan', 'root', '', { AutoCommit => 0 });
my $testresults = DBI->connect('dbi:mysql:database=cpantesters', 'root', '');

my $sth = $testresults->prepare(q{SELECT distinct dist, version, perl, osname FROM cpanstats WHERE state='pass'});
$sth->execute();

my $insert = $cpxxxan->prepare('
    INSERT INTO passes (dist, distversion, normdistversion, perl, osname) VALUES (?, ?, ?, ?, ?)
');
$insert->{PrintWarn} = $insert->{PrintError} = 0;

# foreach my $testresult (@{$results}) {
my $counter = 0;
while(my $testresult = $sth->fetchrow_hashref()) {
  if($testresult->{version} !~ /_/ && $testresult->{perl} !~ /[^\d.]/) {
    $insert->execute(
      $testresult->{dist}, $testresult->{version},
      eval { no warnings; version->new($testresult->{version})->numify() } || 0,
      $testresult->{perl},
      $testresult->{osname}
    ) && $counter++;
    printf("PASS: dist: %s\tversion: %s\tperl: %s\n",
      $testresult->{dist}, $testresult->{version}, $testresult->{perl}
    ) if($verbose);
  } elsif($verbose) {
    printf("SKIP: dist: %s\tversion: %s\tperl: %s\n",
      $testresult->{dist}, $testresult->{version}, $testresult->{perl}
    );
  }
  unless($counter % 5000) {
    print '.';
    $cpxxxan->commit();
  }
}
$cpxxxan->commit();
$cpxxxan->disconnect();
print "\n";
