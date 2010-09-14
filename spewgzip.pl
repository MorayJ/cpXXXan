#!/usr/local/bin/perl

use strict;
use warnings;

use CGI;
my $q = CGI->new();

if($q->param('what') eq '02packages') {
  print "Content-type: text/plain\n\n";
  exec('/bin/gzip', '-dc', 'modules/02packages.details.txt.gz');
} else {
  print "Content-type: text/html\n\nNaughty naughty";
}
