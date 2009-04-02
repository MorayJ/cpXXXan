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

my $cpxxxan = DBI->connect('dbi:mysql:database=cpXXXan', 'root', '');

my @modules = ();
my $query = qq{
    SELECT DISTINCT dist, distversion
      FROM passes p1
     WHERE normdistversion=(
             SELECT MAX(normdistversion)
               FROM passes p2
              WHERE p1.dist=p2.dist AND
                    perl='$perl'
           )
};
my $dist_maxdistversion = $cpxxxan->selectall_arrayref($query, {Slice => {}});
foreach my $record (@{$dist_maxdistversion}) {
    printf("DIST: %s: %s\n", $record->{dist}, $record->{distversion});
    my $query = q{
        SELECT module, modversion, file
	  FROM modules, dists
	 WHERE modules.dist=dists.dist AND
	       modules.distversion=dists.distversion AND
	       modules.dist='}.$record->{dist}.q{' AND
	       modules.distversion='}.$record->{distversion}.q{'
    };
    my $modules = $cpxxxan->selectall_arrayref($query, {Slice => {}});
    foreach my $module (@{$modules}) {
        printf("MOD:    %s: %s %s\n", map { $module->{$_} } qw(module modversion file));
	push @modules, $module;
    }
}

mkdir CPXXXANROOT."/cp${perl}an";
mkdir CPXXXANROOT."/cp${perl}an/modules";
mkdir CPXXXANROOT."/cp${perl}an/authors";

unlink CPXXXANROOT."/cp${perl}an/authors/01mailrc.txt.gz";
unlink CPXXXANROOT."/cp${perl}an/modules/03modlist.data.gz";
unlink CPXXXANROOT."/cp${perl}an/authors/id";

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
print $packagesfile "Line-Count: ".@modules."\n";
print $packagesfile "Last-Updated: ".HTTP::Date::time2str()."\n";
print $packagesfile "\n";
print $packagesfile sprintf(
    "%s %s %s\n", $_->{module}, $_->{modversion}, $_->{'file'}
) foreach (sort { $a->{module} cmp $b->{module} } @modules);
close($packagesfile);
system(qw(gzip -9f), "cp${perl}an/modules/02packages.details.txt");
