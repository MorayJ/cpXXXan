use strict;
use warnings;

use Test::More tests => 12;

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
is_deeply(
    $archive->modules(),
    { 'Class::CanBeA' => 1.2 },
    "modules in /t/ and /inc/ etc are ignored"
);

ok($archive->dist() eq 'Class-CanBeA', 'dist() works (got '.$archive->dist().')');
ok($archive->distversion() eq '1.2', 'distversion() works (got '.$archive->distversion().')');

eval { CPXXXAN::FileIndexer->new('t/perl-5.6.2.tar.gz') };
ok($@ =~ /Can't index perl itself \(perl-5.6.2\)/, "refuse to index perl*");
eval { CPXXXAN::FileIndexer->new('t/ponie-2.tar.gz') };
ok($@ =~ /Can't index perl itself \(ponie-2\)/, "refuse to index ponie*");
eval { CPXXXAN::FileIndexer->new('t/kurila-1.14_0.tar.gz') };
ok($@ =~ /Can't index perl itself \(kurila-1.14_0\)/, "refuse to index kurila*");
