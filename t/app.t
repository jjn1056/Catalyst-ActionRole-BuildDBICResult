use strict;
use warnings;
use Test::More 0.89;
use HTTP::Request::Common qw/GET POST DELETE/;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

ok my $defaults = TestApp->controller('Inherit')->action_for('defaults'),
  'all defaults';

isa_ok $defaults, 'Catalyst::Action';

is_deeply $defaults->store, {method=>'get_model'},
  'default store';

is_deeply $defaults->find_condition, [{constraint_name=>'primary'}],
  'default find_condition';

ok !$defaults->auto_stash, 'default auto_stash';
ok !$defaults->detach_exceptions, 'default detach_exceptions';

ok my $store_as_str = TestApp->controller('Inherit')->action_for('store_as_str'),
  'coerce store from string';

is_deeply $store_as_str->store, {model=>'User'},
  'store coerced to model=>User';

ok my $find_cond_as_str = TestApp->controller('Inherit')->action_for('find_cond_as_str'),
  'coerce store from string'f

is_deeply $find_cond_as_str->find_condition, [{constraint_name=>'unique_email'}],
  'find_condition coerced to constraint_name=>unique_email';

ok my $find_cond_as_cond = TestApp->controller('Inherit')->action_for('find_cond_as_cond'),
  'coerce find_condition from hashred';

is_deeply $find_cond_as_cond->find_condition, [{constraint_name=>'social_security'}],
  'find_condition coerced to constraint_name=>social_security';

ok my $find_cond_as_cond2 = TestApp->controller('Inherit')->action_for('find_cond_as_cond2'),
  'coerce find_condition from columns';

is_deeply $find_cond_as_cond2->find_condition, [{columns=>['id']}],
  'find_condition coerced to columns=>id';


done_testing;

__END__


ok my $defaults = request(GET '/inherit/defaults')->content,
  'Got store content';


use Data::Dump 'dump';
warn dump $defaults;

warn dump TestApp->controller('Inherit')->action_for('defaults')->store;

