use strict;
use warnings;

use Test::More tests => 26;

use CPXXXAN::FileIndexer;
use File::Find::Rule;

print "# can we read all the different types of file?\n";
foreach my $archive (File::Find::Rule->file()->name('XML-Tiny-DOM-1.0*')->in('t')) {
    is_deeply(
        CPXXXAN::FileIndexer->new($archive)->modules(),
        {
            'XML::Tiny::DOM' => '1.0',
            'XML::Tiny::DOM::Element' => '1.0'
        },
        "can read $archive and find module versions"
    )
}

print "# make sure all the methods work on a good distro\n";
my $archive = CPXXXAN::FileIndexer->new('t/Class-CanBeA-1.2.tar.gz');
ok($archive->dist() eq 'Class-CanBeA', 'dist() works (got '.$archive->dist().')');
ok($archive->distversion() eq '1.2', 'distversion() works (got '.$archive->distversion().')');
ok(!$archive->isdevversion(), 'isdevversion() works for a normal release');
is_deeply($archive->{modules}, {}, '$dist->{modules} isn\'t populated until needed');
is_deeply(
    $archive->modules(),
    { 'Class::CanBeA' => 1.2 },
    "modules in /t/ and /inc/ etc are ignored"
);
is_deeply(
    $archive->modules(),
    { 'Class::CanBeA' => 1.2 },
    "calling ...->modules() twice works"
);
ok($archive->{_modules_runs} == 1, "... but the time-consuming bit is only run once");

$archive = CPXXXAN::FileIndexer->new('t/Class-CanBeA-1.2_1.tar.gz');
ok($archive->isdevversion(), '_ in dist version implies dev release');

print "# miscellaneous errors\n";
$archive = CPXXXAN::FileIndexer->new('t/Bad-Permissions-123.456.tar.gz');
is_deeply($archive->modules(), { 'Bad::Permissions' => 123.456}, "Bad perms handled OK");

print "# various broken \$VERSIONs\n";
{ local $SIG{__WARN__} = sub {};
  $archive = CPXXXAN::FileIndexer->new('t/Foo-123.456.tar.gz');
  is_deeply($archive->modules(), { 'Foo' => undef }, "Broken version == undef");

  $archive = CPXXXAN::FileIndexer->new('t/Bad-Backticks-123.456.tar.gz');
  is_deeply($archive->modules(), { 'Bad::Unsafe' => undef }, 'unsafe `$VERSION` isn\'t executed');
  $archive = CPXXXAN::FileIndexer->new('t/Bad-UseVersion-123.456.tar.gz');
  is_deeply(
      $archive->modules(),
      {
          'Bad::UseVersion'   => '0.0.3',
          'Bad::UseVersionQv' => '0.0.3'
      }, 'use version; $VERSION = qv(...) works');
}

print "# Check that we ignore obviously silly files\n";
eval { CPXXXAN::FileIndexer->new('t/Foo-123.456.ppm.zip') };
ok($@ =~ /looks like a ppm/i, "Correctly fail on a PPM");
eval { CPXXXAN::FileIndexer->new('t/non-existent-file') };
ok($@ =~ /doesn't exist/i, "Correctly fail on non-existent file");
eval { CPXXXAN::FileIndexer->new('MANIFEST') };
ok($@ =~ /isn't the right type/i, "Correctly fail on something that isn't an archive");
eval { CPXXXAN::FileIndexer->new('t/perl-5.6.2.tar.gz') };
ok($@ =~ /Can't index perl itself \(perl-5.6.2\)/, "refuse to index perl*");
eval { CPXXXAN::FileIndexer->new('t/parrot-0.4.13.tar.gz') };
ok($@ =~ /Can't index perl itself \(parrot-0.4.13\)/, "refuse to index parrot*");
eval { CPXXXAN::FileIndexer->new('t/Perl6-Pugs-6.2.13.tar.gz') };
ok($@ =~ /Can't index perl itself \(Perl6-Pugs-6.2.13\)/, "refuse to index pugs");
eval { CPXXXAN::FileIndexer->new('t/ponie-2.tar.gz') };
ok($@ =~ /Can't index perl itself \(ponie-2\)/, "refuse to index ponie*");
eval { CPXXXAN::FileIndexer->new('t/kurila-1.14_0.tar.gz') };
ok($@ =~ /Can't index perl itself \(kurila-1.14_0\)/, "refuse to index kurila*");
