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

my $cpxxxan = DBI->connect(
    'dbi:mysql:database=cpXXXan', 'root', '',
    {
        AutoCommit => 0,
        RaiseError => 1,
    }
);
my $testresults = DBI->connect(
    'dbi:mysql:database=cpantesters', 'root', '',
    { RaiseError => 1 }
);

my $lastpass_sth = $cpxxxan->prepare(q{SELECT `value` FROM cache WHERE `key`="lastpass"});
$lastpass_sth->execute();
my $lastpass = -1;
if(my $lastpass_row = $lastpass_sth->fetchrow_hashref()) {
    $lastpass = $lastpass_row->{value};
    print "$0: already imported up to test result $lastpass\n";
}

my $max_pass_in_db_sth = $testresults->prepare(qq{SELECT MAX(id) id FROM cpanstats});
$max_pass_in_db_sth->execute();
my $max_pass_in_db = $max_pass_in_db_sth->fetchrow_hashref()->{id};

my $passes_sth = $testresults->prepare(qq{SELECT distinct dist, version, perl, osname FROM cpanstats WHERE state='pass' AND id > $lastpass});
$passes_sth->execute();

my $insert = $cpxxxan->prepare('
    INSERT INTO passes (dist, distversion, normdistversion, perl, osname) VALUES (?, ?, ?, ?, ?)
');
$insert->{PrintError} = $insert->{RaiseError} = 0; # just throw dups away

my $counter = 0;
while(my $testresult = $passes_sth->fetchrow_hashref()) {
  if(
    $testresult->{version} !~ /(trial|_)/i && # non-indexed dists
    $testresult->{perl} ne '0' &&             # buggy reports?
    $testresult->{perl} !~ /[^\d.]/           # not interested in patched or rc perls
  ) {
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

unless($lastpass == $max_pass_in_db) {
    my $update_cache_sth = $cpxxxan->prepare("REPLACE INTO cache (`key`, `value`) VALUES ('lastpass', $max_pass_in_db)");
    $update_cache_sth->execute();
    print "\n";
    print "$0: updating cache: imported up to test result $max_pass_in_db\n";
}

$cpxxxan->commit();
print "\n";
