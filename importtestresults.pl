#!/usr/local/bin/perl

use warnings;
use strict;

use DBI;

# Configuration for DRC's laptop and for live
use constant BACKPAN => -e '/web/cpxxxan/backpan'
    ? '/web/cpxxxan/backpan'
    : '/Users/david/BackPAN';
use constant CPXXXANROOT => -e '/web/cpxxxan'
    ? '/web/cpxxxan'
    : '.';

my $cpxxxan = DBI->connect('dbi:SQLite:dbname='.CPXXXANROOT.'/db/cpXXXan');
my $testresults = DBI->connect('dbi:SQLite:dbname='.CPXXXANROOT.'/db/cpanstatsdatabase');

# my $results = $testresults->selectall_arrayref(
#     q{SELECT id, dist, version, perl FROM cpanstats WHERE state='pass'},
#     # q{ AND (dist LIKE 'DBI%' or dist LIKE 'DBD%')},
#     {Slice => {}}
# );
my $sth = $testresults->prepare(q{SELECT id, dist, version, perl FROM cpanstats WHERE state='pass'});
$sth->execute();

my $insert = $cpxxxan->prepare('
    INSERT INTO passes (id, dist, distversion, normdistversion, perl) VALUES (?, ?, ?, ?, ?)
');
my $select = $cpxxxan->prepare('SELECT id FROM passes WHERE id = ?');

# foreach my $testresult (@{$results}) {
while(my $testresult = $sth->fetchrow_hashref()) {
    $select->execute($testresult->{id});
    if(!$select->fetchrow_array()) {
        $insert->execute(
            $testresult->{id}, $testresult->{dist}, $testresult->{version},
            eval { version->new($testresult->{version})->numify() } || 0,
            $testresult->{perl}
        );
        printf("id: %s\tdist: %s\tversion: %s\tperl: %s\n",
            $testresult->{id}, $testresult->{dist}, $testresult->{version}, $testresult->{perl});
    }
}
