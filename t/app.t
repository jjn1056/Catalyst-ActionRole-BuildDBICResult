use strict;
use warnings;
use Test::More 0.89;
use HTTP::Request::Common qw/GET POST DELETE/;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

ok my $defaults = request(GET '/inherit/defaults')->content,
  'Got store content';


use Data::Dump 'dump';
warn dump $defaults;

done_testing;

