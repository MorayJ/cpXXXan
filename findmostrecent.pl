#!/usr/local/bin/perl

use warnings;
use strict;

use DBI;
use Data::Dumper;

my $perl = shift();
die("Must specify a perl, eg\n\n  \$ $0 5.6.2\n") unless($perl);

my $cpxxxan = DBI->connect('dbi:SQLite:dbname=db/cpXXXan');

my $data = $cpxxxan->selectall_arrayref(qq{
    SELECT module, modversion, d.dist, d.distversion, d.file
      FROM modules m, dists d
     WHERE m.dist=d.dist AND
           m.distversion=d.distversion AND
           m.dist || '-' || m.distversion = (
              SELECT dist || '-' || distversion
                FROM passes a
               WHERE perl='$perl' AND
                     a.dist = m.dist AND
                     a.distversion = m.distversion AND
                     normdistversion = (
                         SELECT max(normdistversion) FROM passes b
                           WHERE dist=a.dist AND perl='$perl'
                     )
               GROUP BY dist
           )
  ORDER BY module
}, {Slice => {}});
# print Dumper($data);
# exit(0);

open(my $packagesfile, '>', "cp${perl}an/modules/02packages.details.txt")
    || die("Can't write cp${perl}an/modules/02packages.details.txt\n");
print $packagesfile "This is a whitespace-seperated file.\n";
print $packagesfile "Each line is modulename moduleversion filename.\n";
print $packagesfile "\n";
print $packagesfile sprintf(
    "%s\t%s\t%s\n", $_->{module}, $_->{modversion}, $_->{'file'}
) foreach (@{$data});
close($packagesfile);
