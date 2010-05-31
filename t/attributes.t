use strict;
use warnings;
use Test::More;

use_ok 'Catalyst::ActionRole::BuildDBICResult';

{
    package Test::Catalyst::ActionRole::BuildDBICResult;
    use Moose;
    with 'Catalyst::ActionRole::BuildDBICResult';
    sub dispatch {}
}

ok my $defaults = Test::Catalyst::ActionRole::BuildDBICResult->new(),
  'all defaults';

is_deeply $defaults->store, {method=>'get_model'},
  'default store';

is_deeply $defaults->find_condition, [{constraint_name=>'primary'}],
  'default find_condition';

ok !$defaults->auto_stash, 'default auto_stash';
ok !$defaults->detach_exceptions, 'default detach_exceptions';
ok my $regexp = $defaults->check_args_pattern, 'Got the matcher';

ok $defaults->_check_arg('abc'), 'good arg "abc"';
ok $defaults->_check_arg('111'), 'good arg "111"';
ok $defaults->_check_arg(222), 'good arg 222';
ok $defaults->_check_arg(21412343), 'good arg integer';
ok $defaults->_check_arg('995cd3c4-62a6-11df-a00c-7d9949bad02a'), 'good arg UUID';
ok $defaults->_check_arg('johnn@shutterstock.com'), 'good arg email';
ok $defaults->_check_arg('005-82-1111'), 'good arg social security';
ok $defaults->_check_arg('(212)387-1111'), 'good arg phone 1';
ok $defaults->_check_arg('011-86-910-626059'), 'good arg phone 2';


ok ! $defaults->_check_arg(",.<a href=IAMEVIL>evil</a>"),
  'bad arg ",.<a href=IAMEVIL>evil</a>"';

ok ! $defaults->_check_arg(",.<a href=IAMEVIL>evil</a>" x 10),
  'bad arg - too long';

ok my $store_as_str = Test::Catalyst::ActionRole::BuildDBICResult->new(store=>'User'),
  'coerce store from string';

is_deeply $store_as_str->store, {model=>'User'},
  'store coerced to model=>User';

ok my $find_cond_as_str = Test::Catalyst::ActionRole::BuildDBICResult->new(find_condition=>'unique_email'),
  'coerce store from string';

is_deeply $find_cond_as_str->find_condition, [{constraint_name=>'unique_email'}],
  'find_condition coerced to constraint_name=>unique_email';

ok my $find_cond_as_cond = Test::Catalyst::ActionRole::BuildDBICResult->new(find_condition=>{constraint_name=>'social_security'}),
  'coerce store from string';

is_deeply $find_cond_as_cond->find_condition, [{constraint_name=>'social_security'}],
  'find_condition coerced to constraint_name=>social_security';

ok my $find_cond_as_cond2 = Test::Catalyst::ActionRole::BuildDBICResult->new(find_condition=>{columns=>['id']}),
  'coerce store from string';

is_deeply $find_cond_as_cond2->find_condition, [{columns=>['id']}],
  'find_condition coerced to columns=>id';

eval {
    Test::Catalyst::ActionRole::BuildDBICResult->new(find_condition=>{columns=>{a=>'id'}});
};


ok $@, 'got an error from columns=>HashRef as expected';

done_testing;
