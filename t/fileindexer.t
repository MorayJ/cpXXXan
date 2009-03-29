use strict;
use warnings;

use Test::More tests => 21;

use CPXXXAN::FileIndexer;
use File::Find::Rule;

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

my $archive = CPXXXAN::FileIndexer->new('t/Class-CanBeA-1.2.tar.gz');
ok($archive->dist() eq 'Class-CanBeA', 'dist() works (got '.$archive->dist().')');
ok($archive->distversion() eq '1.2', 'distversion() works (got '.$archive->distversion().')');
is_deeply($archive->{modules}, {}, '$dist->{modules} isn\'t populated until needed');
is_deeply(
    $archive->modules(),
    { 'Class::CanBeA' => 1.2 },
    "modules in /t/ and /inc/ etc are ignored"
);
is_deeply(
    $archive->modules(),
    { 'Class::CanBeA' => 1.2 },
    "calling ...->modules() twice works (well duh but more coverage points!"
);

$archive = CPXXXAN::FileIndexer->new('t/Foo-123.456.tar.gz');
is_deeply($archive->modules(), { 'Foo' => undef }, "Broken version == undef");

$archive = CPXXXAN::FileIndexer->new('t/Bad-Permissions-123.456.tar.gz');
is_deeply($archive->modules(), { 'Bad::Permissions' => 123.456}, "Bad perms handled OK");

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
