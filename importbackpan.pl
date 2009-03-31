#!/usr/local/bin/perl

use strict;
use warnings;

use CPXXXAN::FileIndexer;
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

my $dbh = DBI->connect('dbi:mysql:database=cpXXXan', 'root', '', { AutoCommit => 0 });
my $chkexists = $dbh->prepare('SELECT dist FROM dists WHERE dist=? AND distversion=?');
my $insertdist = $dbh->prepare('INSERT INTO dists (dist, distversion, file) VALUES (?, ?, ?)');
my $insertmod  = $dbh->prepare('INSERT INTO modules (module, modversion, normmodversion, dist, distversion) VALUES (?, ?, ?, ?, ?)');

foreach my $distfile (
  File::Find::Rule
    ->file()
    ->name(qr/\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/)
    ->in(BACKPAN.'/authors/id')
) {
    my $dist = eval { CPXXXAN::FileIndexer->new($distfile); };
    next if($@);
    $distfile =~ s!(??{BACKPAN})/authors/id/!!;
    print "$distfile\n";

    # don't index dev versions
    if($dist->isdevversion()) {
        print "  SKIP - dev release\n";
        next;
    }

    $chkexists->execute($dist->dist(), $dist->distversion());
    next if($chkexists->fetchrow_array());

    my %modules = %{$dist->modules()};
    # { local $SIG{__WARN__} = sub {
    #       if(join('', @_) =~ /unsafe code/i) {
    #           open(ERRLOG, '>>errorlog');
    #           print ERRLOG "---\n$distfile\n\n".join('', @_)."\n";
    #           close(ERRLOG);
    #       }
    #   };
    #   %modules = %{$dist->modules()};
    # }
    $insertdist->execute(
        $dist->dist(), $dist->distversion(),
        $distfile
    );
    printf("  %s: %s\n", $dist->dist(), $dist->distversion());
    foreach(keys %modules) {
        $modules{$_} ||= 0;
        # catch broken versions eg Text-PDF-API: 0.01_12_snapshot
        my $normmodversion = eval { version->new($modules{$_})->numify(); } || 0;

        $insertmod->execute($_, $modules{$_}, $normmodversion, $dist->dist(), $dist->distversion());
        printf("    %s: %s (%s)\n", $_, $modules{$_}, $normmodversion);
    }
    $dbh->commit();
}
