use strict;
use warnings;
use Test::More 0.89;
use HTTP::Request::Common qw/GET POST DELETE/;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

ok my $store = request(GET '/store_action')->content,
  'Got store content';

##$store = eval($store);

use Data::Dump 'dump';
warn dump $store;

done_testing;

