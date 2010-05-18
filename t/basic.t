use strict;
use warnings;
use Test::More;

use_ok 'Catalyst::ActionRole::BuildDBICResult';

use FindBin;
use lib "$FindBin::Bin/lib";

use_ok 'TestApp';

use Data::Dump 'dump';

warn dump (TestApp->controller('Root')->action_for('user')->store);
warn dump (TestApp->controller('Root')->action_for('user')->find_condition);

done_testing;
