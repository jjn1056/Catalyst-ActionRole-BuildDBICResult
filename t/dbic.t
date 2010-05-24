use strict;
use warnings;

use Test::More 0.89;
use FindBin;
use lib "$FindBin::Bin/lib";

use TestApp;

ok(TestApp->installdb, 'Setup Database');
ok(TestApp->deploy_dbfixtures, 'Fixtures Deployed');

ok my $schema = TestApp->model('Schema'),
  'got the schema';

ok my @users = &get_ordered_users($schema),
  'got users';

is_deeply [map {$_->email} @users], [
    'john@shutterstock.com',
    'james@shutterstock.com',
    'jay@shutterstock.com',
    'vanessa@shutterstock.com',
], 'Got expected emails';

ok my @roles = &get_ordered_roles($schema),
  'got roles';

is_deeply [map {$_->name} @roles], [
    'member',
    'admin',
], 'Got expected role names';

ok my($john, $james, $jay, $vanessa) = @users,
  'broke out users';

is_deeply [sort map {$_->name} $john->roles->all] ,[qw(admin member)],
  'roles for john';

is_deeply [sort map {$_->name} $james->roles->all] ,[qw(admin member)],
  'roles for james';

is_deeply [sort map {$_->name} $jay->roles->all] ,[qw(member)],
  'roles for jay';

is_deeply [sort map {$_->name} $vanessa->roles->all] ,[qw(admin)],
  'roles for vanessa';

done_testing;

sub get_ordered_users {
    (shift)->
        resultset('User')->
        search({}, {order_by => {-asc=>'user_id'}})->
        all;
}

sub get_ordered_roles {
    (shift)->
        resultset('Role')->
        search({}, {order_by => {-asc=>'role_id'}})->
        all;
}

