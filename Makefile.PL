use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Class::CanBeA',
    VERSION_FROM => 'lib/CPXXXAN/FileIndexer.pm',
    PREREQ_PM    => {
        'Archive::Tar' => 0,
        'Archive::Zip' => 0,
        'File::Find::Rule' => 0
    }
);
