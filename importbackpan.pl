#!/usr/local/bin/perl

use strict;
use warnings;

use CPAN::ParseDistribution;
use CPAN::Checksums qw(updatedir);
use File::Find::Rule;
use DBI;
use version;

# Configuration for DRC's laptop and for live
use constant BACKPAN => -e '/web/cpxxxan/backpan'
    ? '/web/cpxxxan/backpan'
    : '/Users/david/BackPAN';
use constant CPXXXANROOT => -e '/web/cpxxxan'
    ? '/web/cpxxxan'
    : '.';

my $dbh = DBI->connect('dbi:mysql:database=cpXXXan', 'root', '', { AutoCommit => 0, PrintError => 0 });
my $chkexists = $dbh->prepare('SELECT dist FROM dists WHERE dist=? AND distversion=?');
my $insertdist = $dbh->prepare('INSERT INTO dists (dist, distversion, file) VALUES (?, ?, ?)');
my $insertmod  = $dbh->prepare('INSERT INTO modules (module, modversion, dist, distversion) VALUES (?, ?, ?, ?)');

foreach my $distfile (
  File::Find::Rule
    ->file()
    ->name(qr/\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/)
    ->in(BACKPAN.'/authors/id')
) {
    my $dist = eval { CPAN::ParseDistribution->new($distfile); };
    next if($@);
    $distfile =~ s!(??{BACKPAN})/authors/id/!!;

    # don't index dev versions
    next if($dist->isdevversion());

    $chkexists->execute($dist->dist(), $dist->distversion());
    next if($chkexists->fetchrow_array());

    print "FILE: $distfile\n";

    my %modules = %{$dist->modules()};
    $insertdist->execute(
        $dist->dist(), $dist->distversion(),
        $distfile
    ) &&
    printf("DIST:   %s: %s\n", $dist->dist(), $dist->distversion());
    foreach(keys %modules) {
        $modules{$_} ||= 0;

	$insertmod->execute($_, $modules{$_}, $dist->dist(), $dist->distversion()) &&
        printf("MOD:      %s: %s\n", $_, $modules{$_});
    }
    $dbh->commit();
}
$dbh->commit();
$dbh->disconnect();

foreach(File::Find::Rule->directory()->mindepth(3)->in(BACKPAN."/authors/id")) {
    print "Updated $_/CHECKSUMS\n" if(updatedir($_) == 2);
}
