use strict;
use warnings;

use Test::More tests => 15;

use CPXXXAN::FileIndexer;
use File::Find::Rule;

foreach my $archive (File::Find::Rule->file()->name('Class-DBI-ClassGenerator-1.02*')->in('t')) {
    print "# $archive\n";
    $archive = CPXXXAN::FileIndexer->new($archive);
    ok($archive->modules()->{'Class::DBI::ClassGenerator'} eq '1.02',
        "Class::DBI::ClassGenerator parsed OK");
    ok($archive->modules()->{'Class::DBI::ClassGenerator::DBD::mysql'} eq '1.0',
        "Class::DBI::ClassGenerator::DBD::mysql parsed OK");
    ok($archive->modules()->{'Class::DBI::ClassGenerator::DBD::SQLite'} eq '1.0',
        "Class::DBI::ClassGenerator::DBD::SQLiteparsed OK");
}
