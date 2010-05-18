use strict;
use warnings;
use Test::More 0.89;
use HTTP::Request::Common qw/GET POST DELETE/;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

ok my $store_action_res = request(GET '/store_action')->content,
  'Got store content';

ok my $store_actionrole_res = request(GET '/store_actionrole')->content,
  'Got store content';


use Data::Dump 'dump';
warn dump $store_action_res;
warn dump $store_actionrole_res;

done_testing;

