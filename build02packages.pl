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

my($perl, $os, $datetime) = ('') x 3;

while(@ARGV) {
  my $arg = shift();
  if($arg eq '--perl') {
    $perl = shift();
  } elsif($arg eq '--os') {
    $os = shift();
  } elsif($arg eq '--datetime') {
    $datetime = shift();
  }
}

if(!$perl && !$os && !$datetime) {
  die("Must specify a perl, os or datetime\n\n eg\n\n".
      "\$ $0 --perl 5.6.2\n".
      "\$ $0 --os solaris\n".
      "\$ $0 --datetime 2008-10-23Z00:00:00\n\n"
  );
}

my $cpxxxan = DBI->connect('dbi:mysql:database=cpXXXan', 'root', '');

(my $view = "relevantreportsO${os}P${perl}D${datetime}") =~ s/\W//g;

my @modules = ();
my $query = join(' ',
  "CREATE OR REPLACE VIEW $view AS SELECT passes.* FROM",
  join(', ', 'passes', ($datetime ? 'dists' : ())),
  'WHERE',
  join(" AND ",
    ($perl ?     "passes.perl   = '$perl'" : ()),
    ($os   ?     "passes.osname = '$os'" : ()),
    ($datetime ? (
      "passes.dist = dists.dist",
      "passes.distversion = dists.distversion",
      "dists.filetimestamp < '$datetime'"
    ) : ())
  )
);

$cpxxxan->do($query);
$query = qq{
    SELECT DISTINCT dist, distversion
      FROM $view p1
     WHERE normdistversion=(
             SELECT MAX(normdistversion)
	       FROM $view p2
              WHERE p1.dist=p2.dist
	   )
};
my $dist_maxdistversion = $cpxxxan->selectall_arrayref($query, {Slice => {}});

my $modules_sth = $cpxxxan->prepare(q{
    SELECT module, modversion, file
      FROM modules, dists
     WHERE modules.dist=dists.dist AND
           modules.distversion=dists.distversion AND
           modules.dist = ? AND
           modules.distversion = ?
});
foreach my $record (@{$dist_maxdistversion}) {
    printf("DIST: %s: %s\n", $record->{dist}, $record->{distversion})
        if($ENV{VERBOSE});
    $modules_sth->execute($record->{dist}, $record->{distversion});
    my $modules = $modules_sth->fetchall_arrayref({});
    foreach my $module (@{$modules}) {
        printf("MOD:    %s: %s %s\n", map { $module->{$_} } qw(module modversion file))
	    if($ENV{VERBOSE});
	push @modules, $module;
    }
}

(my $mirror = join('-', grep { length($_) } ($perl, $os, $datetime))) =~ s/[^\w.-]//g;

foreach my $regex (qw(-01-01Z000000 -01Z000000)) {
  $mirror =~ s/$regex$//;
}

mkdir CPXXXANROOT."/cp${mirror}an";
mkdir CPXXXANROOT."/cp${mirror}an/modules";
mkdir CPXXXANROOT."/cp${mirror}an/authors";
mkdir CPXXXANROOT."/apache-conf";

unlink CPXXXANROOT."/cp${mirror}an/authors/01mailrc.txt.gz";
unlink CPXXXANROOT."/cp${mirror}an/authors/RECENT-1W.yaml";
unlink CPXXXANROOT."/cp${mirror}an/modules/03modlist.data.gz";
unlink CPXXXANROOT."/cp${mirror}an/authors/id";
unlink CPXXXANROOT."/cp${mirror}an/other-mirrors.shtml";
unlink CPXXXANROOT."/cp${mirror}an/howitworks.shtml";
unlink CPXXXANROOT."/cp${mirror}an/spewgzip.pl";

symlink BACKPAN."/authors/01mailrc.txt.gz",
    CPXXXANROOT."/cp${mirror}an/authors/01mailrc.txt.gz";
symlink BACKPAN."/authors/RECENT-1W.yaml",
    CPXXXANROOT."/cp${mirror}an/authors/RECENT-1W.yaml";
symlink BACKPAN."/modules/03modlist.data.gz",
    CPXXXANROOT."/cp${mirror}an/modules/03modlist.data.gz";
symlink BACKPAN."/authors/id",
    CPXXXANROOT."/cp${mirror}an/authors/id";
symlink CPXXXANROOT."/other-mirrors.shtml",
    CPXXXANROOT."/cp${mirror}an/other-mirrors.shtml";
symlink CPXXXANROOT."/src/howitworks.shtml",
    CPXXXANROOT."/cp${mirror}an/howitworks.shtml";
symlink CPXXXANROOT."/src/spewgzip.pl",
    CPXXXANROOT."/cp${mirror}an/spewgzip.pl";

open(my $packagesfile, '>', "cp${mirror}an/modules/02packages.details.txt")
    || die("Can't write cp${mirror}an/modules/02packages.details.txt: $!\n");
print $packagesfile "Description: This is a whitespace-seperated file.\n";
print $packagesfile "Description: Each line is modulename moduleversion filename.\n";
print $packagesfile "Line-Count: ".@modules."\n";
print $packagesfile "Last-Updated: ".HTTP::Date::time2str()."\n";
print $packagesfile "\n";
print $packagesfile sprintf(
    "%s %s %s\n", $_->{module}, $_->{modversion}, $_->{'file'}
) foreach (sort { $a->{module} cmp $b->{module} } @modules);
close($packagesfile);
system(qw(gzip -9f), "cp${mirror}an/modules/02packages.details.txt");

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
    Options FollowSymLinks Includes ExecCGI
    AllowOverride None
    Order allow,deny
    Allow from all
  </Directory>
</VirtualHost>
};
$apacheconf =~ s/X\.X\.X/$mirror/g;
open(APACHECONF, '>', CPXXXANROOT."/apache-conf/cp${mirror}an.conf")
    || die("Can't write ".CPXXXANROOT."/apache-conf/cp${mirror}an.conf: $!\n");
print APACHECONF $apacheconf;
close(APACHECONF);

my $indexshtml = q{
  <html><head><title>
    CPX.X.XAN: the Comprehensive Perl X.X.X Archive Network
  </title></head><body>
  <TABLE ALIGN=RIGHT><TR><TD WIDTH=100 ALIGN=CENTER>
    <form action="https://www.paypal.com/cgi-bin/webscr" method="post">
      <input type="hidden" name="cmd" value="_xclick">
      <input type="hidden" name="business" value="david@cantrell.org.uk">
      <input type="hidden" name="item_name" value="CPX.X.XAN">
      <input type="hidden" name="no_note" value="1">
      <input type="hidden" name="currency_code" value="EUR">
      <input type="hidden" name="tax" value="0">
      <input type="image" src="https://www.paypal.com/images/x-click-butcc-donate.gif" border="0" name="submit" alt="Make payments with PayPal">
    </form>
  </TD></TR></TABLE>
  <p>
    <a href=http://www.cantrell.org.uk/cgit/cgit.cgi/cpxxxan/>Source code</a> |
    <a href=mailto:david@cantrell.org.uk?Subject=cpX.X.Xan%20bug%20report>Report bugs</a>
  <h1>Welcome to CPX.X.XAN</h1>
  To use this mirror, point your CPAN.pm config at
  http://cpX.X.Xan.barnyard.co.uk/
  <h1>Other similar mirrors</h1>
  <!--#include virtual="other-mirrors.shtml"-->
  <!--#include virtual="howitworks.shtml"-->

  </body></html>};
$indexshtml =~ s/X\.X\.X/$mirror/g;
open(INDEXSHTML, '>', CPXXXANROOT."/cp${mirror}an/index.shtml")
    || die("Can't write ".CPXXXANROOT."/cp${mirror}an/index.shtml: $!\n");
print INDEXSHTML $indexshtml;
close(INDEXSHTML);

chdir(CPXXXANROOT);
opendir(DIR, '.') || die("Can't readdir(".CPXXXANROOT."): $!\n");
open(OTHERMIRRORS, '>', 'other-mirrors.shtml')
    || die("Can't write ".CPXXXANROOT."/other-mirrors.shtml: $!");
print OTHERMIRRORS '<ul>';

my @othermirrors = sort {
  my($A, $B) = map { lc($_) } ($a, $b);
  $A =~s/(^cp|an$)//g;
  $B =~s/(^cp|an$)//g;

  $A =~ /^5/ && $B !~ /^5/ ? -1 :        # cp5* to the top
  $A !~ /^5/ && $B =~ /^5/ ?  1 :
  $A =~ /^[12]/ && $B !~ /^[12]/ ?  1 :  # cp[12]* to the bottom
  $A !~ /^[12]/ && $B =~ /^[12]/ ? -1 :

  $A =~ /^5/ && $B =~ /^5/ ? do {        # two cp5* mirrors
    my @A = split(/\./, $A);
    my @B = split(/\./, $B);

    $A[1] <=> $B[1] ||   # numerically sort version
    $A[2] cmp $B[2];     # alpha-sort point release-os
  } :

  $A cmp $B;
} grep { /^cp.+an/ } readdir(DIR);

print OTHERMIRRORS "<li><a href=http://$_.barnyard.co.uk/>".
  uc(substr($_, 0, 2)).
  lc(substr($_, 2, length($_) - 4)).
  uc(substr($_, -2)).
  "</a>"
    foreach(@othermirrors);
print OTHERMIRRORS '</ul>';
close(OTHERMIRRORS);
closedir(DIR);
