#!/usr/local/bin/perl

use strict;
use warnings;

use CPXXXAN::FileIndexer;
use File::Find::Rule;
use DBI;
use version;

use constant BACKPAN => '/Users/david/BackPAN';

my $dbh = DBI->connect('dbi:SQLite:dbname=db/cpXXXan', '', '', { AutoCommit => 0 });
my $chkexists = $dbh->prepare('SELECT dist FROM dists WHERE dist=? AND distversion=?');
my $insertdist = $dbh->prepare('INSERT INTO dists (dist, distversion, file) VALUES (?, ?, ?)');
my $insertmod  = $dbh->prepare('INSERT INTO modules (module, modversion, dist, distversion) VALUES (?, ?, ?, ?)');

foreach my $distfile (
  File::Find::Rule
    ->file()
    ->name(qr/\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/)
    ->in(BACKPAN.'/authors/id')
) {
    print "$distfile\n";
    my $dist = eval { CPXXXAN::FileIndexer->new($distfile); };
    next if($@);

    # don't index dev versions
    next if($dist->distversion() =~ /_/);

    $chkexists->execute($dist->dist(), $dist->distversion());
    next if($chkexists->fetchrow_array());

    my %modules = %{$dist->modules()};
    $insertdist->execute($dist->dist(), $dist->distversion(), $distfile);
    printf("  %s: %s\n", $dist->dist(), $dist->distversion());
    foreach(keys %modules) {
        $modules{$_} ||= 0;
        # catch broken versions eg Text-PDF-API: 0.01_12_snapshot
        eval { $modules{$_} = version->new($modules{$_})->numify(); };
        $modules{$_} = 0 if($@);

        $insertmod->execute($_, $modules{$_}, $dist->dist(), $dist->distversion());
        printf("    %s: %s\n", $_, $modules{$_});
    }
    $dbh->commit();
}
