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
mkdir CPXXXANROOT."/apache-conf";

unlink CPXXXANROOT."/cp${perl}an/authors/01mailrc.txt.gz";
unlink CPXXXANROOT."/cp${perl}an/modules/03modlist.data.gz";
unlink CPXXXANROOT."/cp${perl}an/authors/id";
unlink CPXXXANROOT."/cp${perl}an/other-mirrors.shtml";

symlink BACKPAN."/authors/01mailrc.txt.gz",
    CPXXXANROOT."/cp${perl}an/authors/01mailrc.txt.gz";
symlink BACKPAN."/modules/03modlist.data.gz",
    CPXXXANROOT."/cp${perl}an/modules/03modlist.data.gz";
symlink BACKPAN."/authors/id",
    CPXXXANROOT."/cp${perl}an/authors/id";
symlink CPXXXANROOT."/other-mirrors.shtml",
    CPXXXANROOT."/cp${perl}an/other-mirrors.shtml";

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

my $apacheconf = q{
<VirtualHost cpX.X.Xan.barnyard.co.uk>
  CustomLog logs/cpX.X.Xan.barnyard.co.uk-access_log combined
  ErrorLog /var/log/apache2/cpX.X.Xan.barnyard.co.uk-error_log
  DocumentRoot "/web/cpxxxan/cpX.X.Xan"
  ServerAdmin webmaster@cantrell.org.uk
  ServerName cpX.X.Xan.barnyard.co.uk

  AddType text/html .shtml
  AddOutputFilter INCLUDES .shtml

  <Directory "/web/cpxxxan/cpX.X.Xan">
    Options FollowSymLinks Includes
    AllowOverride None
    Order allow,deny
    Allow from all
  </Directory>
</VirtualHost>
};
$apacheconf =~ s/X\.X\.X/$perl/g;
open(APACHECONF, '>', CPXXXANROOT."/apache-conf/cp${perl}an.conf")
    || die("Can't write ".CPXXXANROOT."/apache-conf/cp${perl}an.conf\n");
print APACHECONF $apacheconf;
close(APACHECONF);

my $indexshtml = q{
  <html><head><title>
    CPX.X.XAN: the Comprehensive Perl X.X.X Archive Network
  </title></head><body>
  <h1>Welcome to CPX.X.XAN</h1>
  To use this mirror, point your CPAN.pm config at
  http://cpX.X.Xan.barnyard.co.uk/
  <h1>Other similar mirrors</h1>
  <!--#include virtual="other-mirrors.shtml"-->
  </body></html>};
$indexshtml =~ s/X\.X\.X/$perl/g;
open(INDEXSHTML, '>', CPXXXANROOT."/cp${perl}an/index.shtml")
    || die("Can't write ".CPXXXANROOT."/cp${perl}an/index.shtml\n");
print INDEXSHTML $indexshtml;
close(INDEXSHTML);

chdir(CPXXXANROOT);
opendir(DIR, '.') || die("Can't readdir(".CPXXXANROOT.")\n");
open(OTHERMIRRORS, '>', 'other-mirrors.shtml')
    || die("Can't write ".CPXXXANROOT."/other-mirrors.shtml");
print OTHERMIRRORS '<ul>';
print OTHERMIRRORS "<li><a href=http://$_.barnyard.co.uk/>".uc($_)."</a>"
    foreach(grep { /^cp5\.\d+\.\d+an/ } readdir(DIR));
print OTHERMIRRORS '</ul>';
close(OTHERMIRRORS);
closedir(DIR);
