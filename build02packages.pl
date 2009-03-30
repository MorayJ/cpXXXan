#!/usr/local/bin/perl

use warnings;
use strict;

use DBI;
use Data::Dumper;
use HTTP::Date;

# Configuration for DRC's laptop and for live
use constant BACKPAN => -e '/web/cpxxxan/backpan'
    ? '/web/cpxxxan/backpan'
    : '/Users/david/BackPAN';
use constant CPXXXANROOT => -e '/web/cpxxxan'
    ? '/web/cpxxxan'
    : '.';

my $perl = shift();
die("Must specify a perl, eg\n\n  \$ $0 5.6.2\n") unless($perl);

my $cpxxxan = DBI->connect('dbi:SQLite:dbname='.CPXXXANROOT.'/db/cpXXXan');

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

mkdir CPXXXANROOT."/cp${perl}an";
mkdir CPXXXANROOT."/cp${perl}an/modules";
mkdir CPXXXANROOT."/cp${perl}an/authors";
symlink BACKPAN."/authors/01mailrc.txt.gz",
     CPXXXANROOT."/cp${perl}an/authors/01mailrc.txt.gz";
symlink BACKPAN."/modules/03modlist.data.gz",
     CPXXXANROOT."/cp${perl}an/modules/03modlist.data.gz";
symlink BACKPAN."/authors/id",
     CPXXXANROOT."/cp${perl}an/authors/id";

open(my $packagesfile, '>', "cp${perl}an/modules/02packages.details.txt")
    || die("Can't write cp${perl}an/modules/02packages.details.txt\n");
print $packagesfile "Description: This is a whitespace-seperated file.\n";
print $packagesfile "Description: Each line is modulename moduleversion filename.\n";
print $packagesfile "Line-Count: ".@{$data}."\n";
print $packagesfile "Last-Updated: ".HTTP::Date::time2str()."\n";
print $packagesfile "\n";
print $packagesfile sprintf(
    "%s %s %s\n", $_->{module}, $_->{modversion}, $_->{'file'}
) foreach (@{$data});
close($packagesfile);
system(qw(gzip -9f), "cp${perl}an/modules/02packages.details.txt");
