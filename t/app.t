use strict;
use warnings;
use Test::More 0.89;
use HTTP::Request::Common qw/GET POST DELETE/;

use FindBin;
use lib "$FindBin::Bin/lib";

use TestApp;

ok(TestApp->installdb, 'Setup Database');
ok(TestApp->deploy_dbfixtures, 'Fixtures Deployed');

ok my $defaults = TestApp->controller('Inherit')->action_for('defaults'),
  'all defaults';

isa_ok $defaults, 'Catalyst::Action';

is_deeply $defaults->store, {accessor=>'get_model'},
  'default store';

is_deeply $defaults->find_condition, [{constraint_name=>'primary'}],
  'default find_condition';

ok !$defaults->auto_stash, 'default auto_stash';

ok my $store_as_str = TestApp->controller('Inherit')->action_for('store_as_str'),
  'coerce store from string';

is_deeply $store_as_str->store, {model=>'User'},
  'store coerced to model=>User';

ok my $find_cond_as_str = TestApp->controller('Inherit')->action_for('find_cond_as_str'),
  'coerce store from string';

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

use Catalyst::Test 'TestApp';

ok my $user100 = request(GET '/inherit/user_default/100')->content,
  'got user 100';

is $user100, 'user_default,john@shutterstock.com',
  'got expected values for user 100';

ok my $user_email = request(GET '/inherit/user_default/john@shutterstock.com')->content,
  'got user from email';

is $user_email, 'user_default,john@shutterstock.com',
  'got expected values for user email';


ok my $user_notfound = request(GET '/inherit/user_default/xxxx.com')->content,
  'got user from email';

is $user_notfound, 'user_default,notfound',
  'got expected values for user not found';

ok my $user_error = request(GET '/inherit/user_default/error@error.com')->content,
  'generated an error';

is $user_error, 'user_default,error,BOO,notfound',
  'got expected values for user not found';


ok my $user_detach_error = request(GET '/inherit/user_detach_error/100')->content,
  'checking auto stash';

is $user_detach_error, 'user_detach_error,john@shutterstock.com',
  'got expected values for user_detach_error not found';

ok my $user_detach_notfound = request(GET '/inherit/user_detach_error/xxxxxx')->content,
  'checking auto stash';

is $user_detach_notfound, 'user_detach_error,local_notfound',
  'got expected values for user_detach_notfound not found';


ok my $user_accessor_store = request(GET '/inherit/user_accessor_store/100')->content,
  'checking user_accessor_store';

is $user_accessor_store, 'user_accessor_store,john@shutterstock.com',
  'got expected values for user_accessor_store not found';

ok my $chained_multi = request(GET '/inherit/user_role/200/100/user_role_display')->content,
  'checking user_accessor_store';

is $chained_multi, 'user_role_root,member',
  'got expected values for chained_multi not found';


ok my $user_code_store = request(GET '/inherit/user_code_store/101')->content,
  'checking user_code_store';

is $user_code_store, 'user_code_store,james@shutterstock.com',
  'got expected values for user_code_store not found';

ok my $user_code_store2 = request(GET '/inherit/user_code_store2/102')->content,
  'checking user_code_store2';

is $user_code_store2, 'user_code_store2,jay@shutterstock.com',
  'got expected values for user_code_store2 not found';

ok my $global_not_found = request(GET '/inherit/user_code_store2/xxxx')->content,
  'checking global_not_found';

is $global_not_found, 'user_code_store2,global_not_found',
  'got expected values for global_not_found not found';

SKIP: {
    skip 'need better IOC (or something)', 1;
    ok my $role_value_store = request(GET '/inherit/role_value_store/admin')->content,
      'checking role_value_store';
}

ok my $doesuser100 = request(GET '/does/user_default/100')->content,
  'got user 100';

is $doesuser100, 'user_default,john@shutterstock.com',
  'got expected values for user 100';

done_testing;

