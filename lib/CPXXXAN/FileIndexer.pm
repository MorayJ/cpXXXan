package CPXXXAN::FileIndexer;

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = '1.0';

use Cwd qw(getcwd abs_path);
use File::Temp qw(tempdir);
use File::Find::Rule;
use File::Path;
use Data::Dumper;
use Archive::Tar;
use Archive::Zip;

=head1 NAME

CPXXXAN::FileIndexer - index a file from the BackPAN

=head1 DESCRIPTION

Given a file from the BackPAN, this will let you find out what versions
of what modules it contains, the distribution name and version

=head1 SYNOPSIS

    my $dist = CPXXXAN::FileIndexer->new(
        'A/AU/AUTHORID/subdirectory/Some-Distribution-1.23.tar.gz'
    );
    my $modules     = $dist->modules(); # hashref of modname => version
    my $distname    = $dist->dist();
    my $distversion = $dist->distversion();

=head1 METHODS

=head2 new

Constructor, takes a single mandatory argument, which should be a tarball
or zip file from the BackPAN.

=cut

sub new {
    my($class, $file) = @_;
    die("$file doesn't exist\n") if(!-e $file);
    die("$file isn't the right type\n")
        if($file !~ /\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/);
    $file = abs_path($file);

    # dist name and version
    (my $dist = $file) =~ s{(^.*/|\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$)}{}g;
    $dist =~ /^(.*)-(\d.*)$/;
    ($dist, my $distversion) = ($1, $2);
    die("Can't index perl itself ($dist-$distversion)\n") if($dist =~ /^(perl|ponie|kurila)$/);

    bless {
        file    => $file,
        modules => {},
        dist    => $dist,
        distversion => $distversion
    }, $class;
}

# save and restore the cwd
{
    my @dirstack = ();    
    sub _pushd { push @dirstack, getcwd(); }
    sub _popd  { chdir(pop(@dirstack)); }
}

# takes a filename, unarchives it, returns the directory it's been
# unarchived into
sub _unarchive {
    my $file = shift;
    my $tempdir = tempdir(TMPDIR => 1);
    chdir($tempdir);
    if($file =~ /\.zip$/) {
        my $zip = Archive::Zip->new($file);
        $zip->extractTree();
    } elsif($file =~ /\.(tar(\.gz)?|tgz)$/) {
        my $tar = Archive::Tar->new($file, 1);
        $tar->extract();
    } elsif($file =~ /(\.tbz|\.tar\.bz2)$/) {
        open(my $fh, '-|', qw(bzip2 -dc), $file) || die("Can't unbzip2\n");
        my $tar = Archive::Tar->new($fh);
        $tar->extract();
    } elsif($file =~ /\.tar$/) {
        my $tar = Archive::Tar->new($file);
        $tar->extract();
    }
    return $tempdir;
}

# from PAUSE::pmfile::parse_version_safely in mldistwatch.pm
sub _parse_version_safely {
    my($parsefile) = @_;
    my $result;
    local $/ = "\n";
    open(my $fh, $parsefile) or die "Could not open '$parsefile': $!";
    my $inpod = 0;
    while (<$fh>) {
        $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
        next if $inpod || /^\s*#/;
        chop;
        next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
        my $current_parsed_line = $_;
        my $eval = qq{
            package ExtUtils::MakeMaker::_version;
            use vars qw(\$VERSION);
            local $1$2;
            \$$2=undef; do {
                $_
            }; \$$2
        };
        local $^W = 0;
        $result = eval($eval);
        die "_parse_version_safely: ".Dumper({
              eval => $eval,
              line => $current_parsed_line,
              file => $parsefile,
              err => $@,
        }) if $@;
        last;
    }
    close $fh;

    return $result;
}

=head2 modules

Returns a hashref whose keys are module names, and their values are
the versions of the modules.

=cut

sub modules {
    my $self = shift;
    if(!(keys %{$self->{modules}})) {
        _pushd();
        my $tempdir = _unarchive($self->{file});
        _popd();

        # find modules
        my @PMs = grep {
            $_ !~ m{^\Q$tempdir\E/[^/]+/(t|inc|xt)/}
        } File::Find::Rule->file()->name('*.pm')->in($tempdir);
        foreach my $PM (@PMs) {
            local $/ = undef;
            my $version = _parse_version_safely($PM);
            open(my $fh, $PM) || die("Can't read $PM\n");
            $PM = <$fh>;
            close($fh);

            # from PAUSE::pmfile::packages_per_pmfile in mldistwatch.pm
            $PM =~ /\bpackage\s+([\w\:\']+)/;
            if($1) {
                my $module = $1;
                $self->{modules}->{$module} = $version;
            }
        }
        rmtree($tempdir);
    }
    return $self->{modules};
}

=head2 dist

Return the name of the distribution. eg, in the synopsis above, it would
return 'Some-Distribution'.

=cut

sub dist {
    my $self = shift;
    return $self->{dist};
}

=head2 distversion

Return the version of the distribution. eg, in the synopsis above, it would
return 1.23.

=cut

sub distversion{
    my $self = shift;
    return $self->{distversion};
}

=head1 LIMITATIONS, BUGS and FEEDBACK

I welcome feedback about my code, including constructive criticism.
Bug reports should be made using L<http://rt.cpan.org/> or by email,
and should include the smallest possible chunk of code, along with
any necessary XML data, which demonstrates the bug.  Ideally, this
will be in the form of a file which I can drop in to the module's
test suite.

=cut

# =head1 SEE ALSO

=head1 AUTHOR, COPYRIGHT and LICENCE

Copyright 2009 David Cantrell E<lt>david@cantrell.org.ukE<gt>

This software is free-as-in-speech software, and may be used,
distributed, and modified under the terms of either the GNU
General Public Licence version 2 or the Artistic Licence.  It's
up to you which one you use.  The full text of the licences can
be found in the files GPL2.txt and ARTISTIC.txt, respectively.

=head1 CONSPIRACY

This module is also free-as-in-mason software.

=cut

1;
