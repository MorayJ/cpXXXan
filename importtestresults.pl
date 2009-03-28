#!/usr/local/bin/perl

use warnings;
use strict;

use DBI;

my $cpxxxan = DBI->connect('dbi:SQLite:dbname=db/cpXXXan');
my $testresults = DBI->connect('dbi:SQLite:dbname=db/cpanstatsdatabase');

my $results = $testresults->selectall_arrayref(
    q{SELECT id, dist, version, perl FROM cpanstats WHERE state='pass'},
    {Slice => {}}
);

my $sth = $cpxxxan->prepare('
    INSERT INTO passes (id, dist, distversion, perl) VALUES (?, ?, ?, ?)
');

foreach(@{$results}) {
    if($sth->execute($_->{id}, $_->{dist}, $_->{version}, $_->{perl})) {
        printf("id: %s\tdist: %s\tversion: %s\tperl: %s\n",
            $_->{id}, $_->{dist}, $_->{version}, $_->{perl});
    }
}
