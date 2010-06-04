package Catalyst::ActionRole::BuildDBICResult;

BEGIN {
  $Catalyst::Does::BuildDBICResult::VERSION = '0.01';
}

use Moose::Role;
use namespace::autoclean;
use Perl6::Junction qw(any all);
use Moose::Util::TypeConstraints;
use Catalyst::Exception;
use Try::Tiny qw(try catch);

requires 'name', 'dispatch';

subtype 'StoreType',
    as 'HashRef',
    where {
        my ($store_type, @extra) = keys %$_;
        my $return;
        unless(@extra) {
            if($store_type eq any(qw/model method stash value code/)) {
                $return = 1;
            } else {
                $return = 0;
            }
        } else {
            $return = 0;
        }
        $return;
    };

coerce 'StoreType',
    from 'Str',
    via { +{model=>$_} };

has 'store' => (
    isa => 'StoreType',
    is => 'ro',
    coerce => 1,
    required => 1,
    lazy => 1,
    default => sub { +{method=>'get_model'} },
);

my $find_condition_tc = subtype 'FindCondition',
    as 'HashRef',
    where {
        my @keys = keys(%$_);
        my $return;
        if(
            (any(@keys) eq any(qw/constraint_name columns/)) and
            (all(@keys) eq any(qw/constraint_name match_order columns/))
        ) {
            if($_->{columns} and ref $_->{columns}) {
                $return = ref $_->{columns} eq 'ARRAY' ? 1 : 0;
            } else {
                $return = 1;
            }
        } else {
            $return = 0;
        }
        $return;
    };

coerce 'FindCondition',
    from 'Str',
    via { +{constraint_name=>$_} },
    from 'ArrayRef',
    via { +{columns=>$_} };

subtype 'FindConditions',
    as 'ArrayRef[FindCondition]';

coerce 'FindConditions',
    from 'FindCondition',
    via { +[$_] },
    from 'Str',
    via { +[{constraint_name=>$_}] },
    from 'ArrayRef',
    via {
        [map { $find_condition_tc->coerce($_) } @$_];
    };

has 'find_condition' => (
    isa => 'FindConditions',
    is => 'ro',
    coerce => 1,
    required => 1,
    lazy => 1,
    default => sub { +[{constraint_name=>'primary'}] },
);

has 'auto_stash' => (is=>'ro', required=>1, lazy=>1, default=>0);
has 'detach_exceptions' => (is=>'ro', required=>1, lazy=>1, default=>0);

subtype 'HandlerActionInfo',
    as 'HashRef',
    where {
        my @keys = keys(%$_);
        if(
            ($#keys == 0) and
            (all(@keys) eq any(qw/forward detach visit go/))
        ) {
            1;
        } else {
            0;
        }
    };

subtype 'Handlers',
    as 'HashRef[HandlerActionInfo]',
    where {
        my @keys = %$_;
        if(all(@keys) eq any(qw/found notfound error/)) {
            1;
        } else {
            0;
        }
    };

coerce 'Handlers',
    from 'HashRef[Str]',
    via { +{forward=>$_} };

has 'handlers' => (
    is => 'ro',
    isa => 'Handlers',
    coerce => 1,
);

## refactor please! What a messssssss!
sub prepare_resultset {
    my ($self, $controller, $ctx) = @_;
    my @args = @{$ctx->req->args};
    my ($store_type, $store_value) = %{$self->store};

    my $resultset;
    if($store_type eq 'model') {
        $resultset = $ctx->model($store_value);
    } elsif($store_type eq 'method') {
        if(my $code = $controller->can($store_value)) {
            $resultset = $controller->$code($self,$ctx, @args);
        } else {
            Catalyst::Exception->throw(message=>"$store_value is not a method on $controller");
        }
    } elsif($store_type eq 'stash') {
        $resultset = $ctx->stash->{$store_value};
    } elsif($store_type eq 'value') {
        $resultset = $store_value;
    } elsif($store_type eq 'code') {
        ## $action, $controller, $ctx, @args)
        $resultset = $self->$store_value($controller, $ctx. @args);
    } else {
        Catalyst::Exception->throw(
            message=>"'$store_type' is not recognized.  Please review your 'store' setting ($store_value) for $self"
        );
    }

    if($resultset && ref $resultset && $resultset->isa('DBIx::Class::ResultSet')) {
        return $resultset;
    } else {
        Catalyst::Exception->throw(
            message=>"Your defined Store ($store_type) failed to return a proper ResultSet",
        );        
    }
}

sub columns_from_find_condition {
    my ($self, $resultset, $find_condition) = @_;
    my @columns;
    if(my $constraint_name = $find_condition->{constraint_name}) {
        @columns = $resultset->result_source->unique_constraint_columns($constraint_name);
    } else {
        @columns = @{$find_condition->{columns}};
        unless($resultset->result_source->name_unique_constraint(\@columns)) {
            my $columns = join ',', @columns;
            my $name = $resultset->result_source->name;
            Catalyst::Exception->throw(
                message=>"Fields [$columns] don't match any constraints in resultsource: $name",
            );           
        }
    }
    return @columns;
}

sub result_from_columns {
    my ($self, $resultset, $args, $columns) = @_;
    my %find_condition = map {$_ => shift(@$args)} @$columns;
    return $resultset->find(\%find_condition);
}

around 'dispatch' => sub  {
    my $orig = shift @_;
    my $self = shift @_;
    my $ctx = shift @_;

    my ($row, $err);
    my $controller = $ctx->component($self->class);
    my $resultset = $self->prepare_resultset($controller,$ctx);
 
   for my $find_condition( @{$self->find_condition}) {

        my @args = @{$ctx->req->args};
        my @columns = $self->columns_from_find_condition($resultset, $find_condition);

        unless(@columns == @args) {
            $ctx->error(
                sprintf "Arguments %s don't match the given find condition %s",
                join(',', @args),
                join(',', @columns),
            );
        }

        try {
            $row = $self->result_from_columns($resultset, \@args, \@columns);
        } catch {
            $err = $_;
        };
        
        if($row) {
            $ctx->log->debug("Found row with ". join(',', @columns));
            last;
        } else {
            $ctx->log->debug("Can't find with ". join(',', @columns));
        }

        last if $err;
    }

    my $base_name = $self->name;
    my $return_action_result = $self->$orig($ctx, @_);

    if($err) {
        if(my $error_code = $controller->action_for($base_name .'_ERROR')) {
             $ctx->forward( $error_code, [$err, @{$ctx->req->args}] );
        } else {
            $ctx->log->debug("No error action, logging exception.");
            $ctx->error($err);
        }
    } 

    if($row) {
        if(my $found_code = $controller->action_for($base_name .'_FOUND')) {
            $return_action_result = $ctx->forward( $found_code, [$row, @{$ctx->req->args}] );
        } else {
            $ctx->log->debug("No found action, skipping.");
        }
    } else {
        if(my $notfound_code = $controller->action_for($base_name .'_NOTFOUND')) {
            $return_action_result =  $ctx->forward( $notfound_code, $ctx->req->args );
        } else {
            $ctx->log->debug("No notfound action, skipping.");
        }
    }

    return $return_action_result;
};

1;

=head1 NAME

Catalyst::Does::BuildDBICResult

=head1 SYNOPSIS

The following is example usage for this role.

    package MyApp::Controller::MyController;

    use Moose;
    use namespace::autoclean;

    BEGIN { extends 'Catalyst::Controller::ActionRole' }
 
    __PACKAGE__->config(
        action_args => {
            user => { store => 'DBICSchema::User' },
        }
    );

    sub user :Path :Args(1) 
        :Does('FindsDBICResult')
    {
        my ($self, $ctx, $id) = @_;
        ## This is always executed, and is done so first, unless the attempt to
        ## find the argument results in an exception, in which case the rescue
        ## handler is called first.  Afterwards, forward to either *_FOUND or 
        ## *_NOTFOUND actions and continue processing.
    }

    sub  user_FOUND :Action {
        my ($self, $ctx, $user, $id) = @_;
    }

    sub user_NOTFOUND :Action {
        my ($self, $ctx, $id) = @_;
         $ctx->go('/error/not_found'); 
    }

    ## If *_ERROR is not defined, rethrow any errors as a L<Catalyst::Exception>
    sub user_ERROR :Action {
        my ($self, $ctx, $error, $id = @_;
        $ctx->log->error("Error finding User with $id: $error")
    }

Please see the test cases for more detailed examples.

=head1 DESCRIPTION

This is a <Moose::Role> intending to enhance any L<Catalyst::Action>, typically
applied in your L<Catalyst::Controller::ActionRole> based controllers, although
it can also be consumed as a role on your custom actions.

Mapping incoming arguments to a particular result in a L<DBIx::Class> based model
is a pretty common development case.  Making choices based on the return of that
result is also quite common.  Additionally, properly 'untainting' incoming
arguments and catching exceptions are equally important parts of handling this
development case correctly. The goal of this action role is to reduce the amount
of boilerplate code you have to write to get these common cases completed. It 
is intented to encapsulate all the boilerplate code required to perform this
task correctly and safely.

Basically we encapsulate the logic: "For a given DBIC resultset, does the find
condition return a valid result given the incoming arguments?  Depending on the
result, delegate to an assigned handlers until the result is handled."

A find condition maps incoming action arguments to a DBIC unique
constraint.  This condition resolves to one of three results: "FOUND", 
"NOTFOUND", "ERROR".  Result condition "FOUND" returns when the find condition
finds a single row against the defined ResultSet, NOTFOUND when the find
condition fails and ERROR when trying to resolve the find condition results
in a catchable error.

Based on the result condition we automatically call an action whose name 
matches a default template, as in the SYNOPSIS above.  You may also override
this default template via configuration.  This makes it easy to configure
common results, like NOTFOUND, to be handled by a common action.

Be default an ERROR result also calls a NOTFOUND (after calling the ERROR
handler), since both conditions logically match.  However ERROR is delegated to
first, so if you go/detach in that action, the NOTFOUND will not be called.

When dispatching a result condition, such as ERROR, FOUND, etc., to a handler,
we follow a hierachy of defaults, followed by any handlers added in configuration.
The first matching handler takes the request and the remaining are ignored.

It is not the intention of this action role to handle 'kitchen sink' tasks
related to accessing the your DBIC model.  If you need more we recommend looking
at L<Catalyst::Controller::DBIC::API> for general API access needs or for a
more complete CRUD setup check out L<CatalystX::CRUD> or L<Catalyst::Plugin::AutoCRUD>.

=head1 EXAMPLES

Assuming "model("DBICSchema::User") is a L<DBIx::Class::ResultSet>, we can
replace the following code:

    package MyApp::Controller::MyController;

    use Moose;
    use namespace::autoclean;

    BEGIN { extends 'Catalyst::Controller' }

    sub user :Path :Args(1) {
        my ($self, $ctx, $user_id) = @_;
        if($user_id =~ m/$acceptable_arg_pattern_regexp/) {
            my $user;
            eval {
                $user = $ctx->model('DBICSchema::User')
                  ->find({user_id=>$user_id});
                1;
            } or $ctx->forward('/error/server_error');

            if($user) {
                ## You Found a User, do something useful...
            } else {
                ## You didn't find a User (or got an error).
                $ctx->go('/error/not_found');
            }
        } else {
            ## Incoming argument does not conform to acceptable pattern
            $ctx->go('/error/not_found');
        }
    }

With something like this code:

    package MyApp::Controller::MyController;

    use Moose;
    use namespace::autoclean;

    BEGIN { extends 'Catalyst::Controller::Does' }
 
   __PACKAGE__->config(
        action_args => {
            user => { store => 'Schema::User' },
        }
    );

    sub user :Path :Args(1) 
        :Does('FindsDBICResult')
    {
        my ($self, $ctx, $arg) = @_;
    }

    sub  user_FOUND :Action {
        my ($self, $ctx, $user, $arg) = @_;
    }

    sub user_NOTFOUND :Action {
        my ($self, $ctx, $arg) = @_;
         $ctx->go('/error/not_found')
    }

    sub user_ERROR :Action {
        my ($self, $ctx, $error, $arg) = @_;
        $ctx->log->error("Error finding User: $error");
    }

Or, if you don't need to handle any code for your exceptional conditions (such
as NOTFOUND or ERROR) you can move more to the configuration:

    package MyApp::Controller::MyController;

    use Moose;
    use namespace::autoclean;

    BEGIN { extends 'Catalyst::Controller::Does' }
 
   __PACKAGE__->config(
        action_args => {
            user => {
                store => 'Schema::User',
                handlers => {
                    notfound => { go => '/error/notfound' },
                    error => { go => '/error/server_error' },
                },
             },
        },
    );

    sub user :Path :Args(1) 
        :Does('FindsDBICResult')
    {
        my ($self, $ctx, $arg) = @_;
    }

    sub  user_FOUND :Action {
        my ($self, $ctx, $user, $arg) = @_;
    }

Another example this time with Chained actions and a more complex DBIC result
find condition, as well as custom exceptin handlers:

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { stash => 'user_rs' },
                find_condition => { columns => ['email'] },
                auto_stash => 1,
                handlers => {
                    notfound => { detach => '/error/notfound' },
                    error => { go => '/error/server_error' },
                },
            },
        },
    );

    sub root :Chained :CaptureArgs(0) {
        my ($self, $ctx) = @_;
        $ctx->stash(user_rs=>$ctx->model('DBICSchema::User'));
    }

    sub user :Chained('root') :CaptureArgs(1) 
        :Does('FindsDBICResult') {}

    sub details :Chained('user') :Args(0) 
    {
        my ($self, $ctx, $arg) = @_;
        my $user_details = $ctx->stash->{user};
        ## Do something with the details, probably delagate to a View, etc.
    }

This would replace something like the following custom code:

    sub root :Chained :CaptureArgs(0) {
        my ($self, $ctx) = @_;
        $ctx->stash(user_rs=>$ctx->model('DBICSchema::User'));
    }

    sub user :Chained('root') :CaptureArgs(1) {
        my ($self, $ctx, $email) = @_;
        my $user_rs = $ctx->stash->{user_rs};
        if($user_id =~ m/$acceptable_arg_pattern_regexp/) {
            my $user;
            eval {
                $user = $user_rs->find({email=>$email});
                1;
            } or $ctx->go('/error/server_error');

            if($user) {
                $ctx->stash(user => $user);
            } else {
                ## You didn't find a User (or got an error).
                $ctx->detach('/error/not_found');
            }
        } else {
            ## Incoming argument does not conform to acceptable pattern
            $ctx->detach('/error/not_found');
        }
    } 

    sub details :Chained('user') :Args(0) 
    {
        my ($self, $ctx, $arg) = @_;
        my $user_details = $ctx->stash->{user};
        ## Do something with the details, probably delagate to a View, etc.
    }

NOTE: Variable and class names above choosen for documentation readability
and should not be considered best practice recomendations. For example, I would
not name my L<Catalyst::Model::DBIC::Schema> based model 'DBICSchema'.
 
=head1 ATTRIBUTES

This role defines the following attributes.

=head2 store

This defines the method by which we get a L<DBIx::Class::ResultSet> suitable
for applying a L</find_condition>.  The canonical form is a HashRef where the
keys / values conform to the following template.

    { model||method||stash||value||code => Str||Code }

Details follow:

=over 4

=item {model => '$dbic_model_name'}

Store comes from a L<Catalyst::Model::DBIC::Schema> based model.

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { model  => 'DBICSchema::User' },
            },
        }
    );

This retrieves a L<DBIx::Class::ResultSet> via $ctx->model($dbic_model_name).

=item {method => '$get_resultset'}

Calls a method on the containing controller.

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { method => 'get_user_resultset' },
            },
        }
    );

    sub user :Action :Does('BuildDBICResult') :Args(1) {
        my ($self, $ctx, $arg) = @_;
    }

    sub get_user_resultset {
        my ($self, $action, @args) = @_;
        ...
        return $resultset;
    }

The containing controller must define this method and it must return a proper
L<DBIx::Class::ResultSet> or an exception is thrown.

Method is passed the action instance and the arguments passed into the action
from the dispatcher.

=item {stash => '$name_of_stash_key' }

Looks in $ctx->stash->{$name_of_stash_key} for a resultset.

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { stash => 'user_rs' },
            },
        }
    );

This is useful if you are descending a chain of actions and modifying or
restricting a resultset based on the context or other logic.

=item {value => $resultset_object}

Assigns a literal value, expected to be a value L<DBIx:Class::ResultSet>

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { value => $schema->resultset('User') },
            },
        }
    );

Useful if you need to directly assign an already prepared resultset as the 
value for doing $rs->find against.  You might use this with a more capable
inversion of control container, such as L<Catalyst::Plugin::Bread::Board>.

=item {code => sub { ... }}

Similar to the 'value' option above, might be useful if you are doing tricky
setup.  Should be a subroutine reference that return a L<DBIx::Class::ResultSet>

    sub get_me_a_resultset {
        my ($action, $controller, $ctx, @args) = @_;
        ## Some custom instantiation needs
        return $resultset;
    }

    __PACKAGE__->config(
        action_args => {
            user => {
                store => { code => \&get_me_a_resultset },
            },
        }
    );

The coderef gets the following arguments: $action, which is the action object
for the L<Catalyst::Action> based instance, $controller, which is the controller
object containing the action, $ctx, which is the current context, and an array
of arguments which are the arguments passed to the action.

=back

NOTE: In order to reduce extra boilerplate and needless typing in your
configuration, we will automatically try to coerce a String value to one of the
listed HashRef values.  We coerce depending on the String value given based on
the following criteria:

=over 4

=item store => Str

We also automatically coerce a Str value of $str to {model => $str}, IF $str
begins with an uppercased letter or the string contains "::", indicating the
value is a namespace target, and to {stash => $str} otherwise.  We believe
this is a common case for these types.

    __PACKAGE__->config(
        action_args => {
            user => {
                ## Internally coerced to "store => {model=>'DBICSchema::User'}".
                store => 'DBICSchema::User',
            },
        }
    );


    ## Perl practices indicate you should Title Case object namespaces, but
    ## in case you have some of these we try to detect and do the right thing.

    __PACKAGE__->config(
        action_args => {
            user => {
                ## Internally coerced to "store => {model=>'schema::user'}".
                store => 'schema::user',
            },
        }
    );

    __PACKAGE__->config(
        action_args => {
            user => {
                ## Internally coerced to "store => {stash =>'user_rs'}".
                store => 'user_rs',
            },
        }
    );

=item store => blessed $object isa L<DBIx::Class::ResultSet>

If the value is a blessed object of the correct type (L<DBIx::Class::ResultSet>)
we just assume your want a 'value' type.

    __PACKAGE__->config(
        action_args => {
            user => {
                ## Internally coerced to "store => {value => $user_resultset}".
                store => $user_resultset,
            },
        }
    );

=item store => CodeRef

If the value is a subroutine reference, we coerce to the coderef type.

    __PACKAGE__->config(
        action_args => {
            user => {
                ## Internally coerced to "store => { coderef => sub {...} }".
                store => sub { ... },
            },
        }
    );

=back

Coercions are of course optional; you may wish to skip them to you want better
self documenting code.

=head2 find_condition

This should a way for a given resultset (defined in L</store> to find a single
row.  Not finding anything is also an accepted option.  Everything else is some
sort error.

Canonically, the find condition is an arrayref of unique constraints, as 
defined in L<DBIx::Class::ResultSource> either with 'set_primary_key' or with
'add_unique_constraint'. for example:

    ## in your DBIx::Class ResultSource
	__PACKAGE__->set_primary_key('category_id');
	__PACKAGE__->add_unique_constraint(category_name_is_unique => ['name']);

    ## in your (canonical expressed) L<Catalyst::Controller>
    __PACKAGE__->config(
        action_args => {
            category => {
                store => {model => 'DBICSchema::Category'},
                find_condition => [
                    'primary',
                    'category_name_is_unique',
                ],
            }
        }
    );

    sub category :Path :Args(1) :Does('FindsDBICResult') {
        my ($self, $ctx, $category_arg) = @_;
    }

    sub category_FOUND :action {}
    sub category_NOTFOUND :action {}
    sub category_ERROR :action {}

In this example $category_arg would first be checked as a primary key, and then
as a category name field.  This allows you a degree of polymorphism in your url
design or web api.

Each unique constraint refers to one or more columns in your database.  Incoming
args to an action are mapped to columns by the order they are defined in the
primary key or unique constraint condition, or in a configured order.  Example
of reordering multi field unique constraints:

    ## in your DBIx::Class ResultSource
	__PACKAGE__->add_unique_constraint(user_role_is_unique => ['user_id', 'role_id']);

    ## in your L<Catalyst::Controller>
    __PACKAGE__->config(
        action_args => {
            user_role => {
                store => {model => 'DBICSchema::UserRole'},
                find_condition => [
                    {
                        constraint_name => 'category_name_is_unique',
                        match_order => ['role_id','user_id'],
                    }
                ],
            }
        }
    );

Additionally since most developers don't bother to name their unique constraints
we allow you to specify a constraint by its column(s):

    ## in your DBIx::Class ResultSource
	__PACKAGE__->add_unique_constraint(['user_id', 'role_id']);

    ## in your L<Catalyst::Controller>
    __PACKAGE__->config(
        action_args => {
            user_role => {
                store => {model => 'DBICSchema::UserRole'},
                find_condition => [
                    {
                        columns => ['user_id','role_id'],
                        match_order => ['role_id','user_id'],
                    }
                ],
            }
        }
    );

    sub role_user :Path :Args(2) {
        my ($self, $ctx, $role_id, $user_id) = @_;
    }

Please note that 'columns' is used merely to discover the unique constraint 
which has already been defined via 'add_unique_constraint'.  You cannot name
columns which are not already marked as fields in a unique constraint or in a
primary key.  Additionally the order of columns used in 'columns' is not 
relevent or meaningful; if you need to control how your action args order map
to DBIC fields, use 'match_order'


We automatically handle the common case of mapping a single field primary key
to a single argument in a controller "Args(1)".  If you fail to defined a
find_condition this is the default we use.  See the L<SYNOPSIS> for this
example.

This is an API overview, please see L</FIND CONDITIONS DETAILS> for more.

=head2 detach_exceptions

    detach_exceptions => 1, # default is 0

By default we $ctx->forward to expection handlers (NOTFOUND, ERROR), which we
believe gives you the most flexibility.  You can always detach within a handling
action.  However if you wish, you can force NOTFOUND or ERROR to detach instead
of forwarding by setting this option to any true value.

=head2 auto_stash

If this is true (default is false), upon a FOUND result, place the found
DBIC result into the stash.  If the value is alpha_numeric, that value is
used as the stash key.  if its either 1, '1', 'true' or 'TRUE' we default
to the name of the method associated with the consuming action.  For example:

    __PACKAGE__->config(
        action_args => {
            user => { store => 'DBICSchema::User', auto_stash => 1 },
        },
    );

    sub user :Path :Args(1) {
        my ($self, $ctx, $user_id) = @_;
        ## $ctx->stash->{user} is defined if $user_id is found.
    }

This could be combined with the L</handlers> attribute to make fast mocks and
prototypes.  See below

=head2 handlers

Expects a HashRef and is optional.

By default we delegate result conditions (FOUND, NOTFOUND, ERROR) to an action
from a list of predefined options.  These predefined options work very similarly
to L<Catalyst::Action::REST>, so if you are familiar with that system this will
seem very natural.

First we try to match a result to an action specific handler, which follows the
template $action_name .'_'. $result_condition.  So for an action named 'user'
which is consuming this role, there could be actions 'user_FOUND', 'user_NOTFOUND',
'user_ERROR' which would get $ctx->forwarded too AFTER executing the body of
the consuming action.

If this template fails to match (as in you did not define such an action in
the same L<Catalyst::Controller> subclass as your consuming action) we then
look for a 'global' action in the controller, which is in the form of an action
named $result_condition (basically actions named FOUND, NOTFOUND or ERROR).

This could be useful if you wish to centralize control of execeptional 
conditions.  For example you could create a base controller or controller role
that defined the "NOTFOUND" or "ERROR" actions and then extend or consume that 
into the controller containing actions using this action role.  

However there may be cases where you need direct control over the action that
get's called for a given result condition.  In this case you can add handlers
to the end of the lookup list for a given result condition.  This is a HashRef
that accepts one or more of the following keys: found, notfound, error. Example:

    handlers => {
        found => { forward|detach|go|visit => $found_action_name },
        notfound => { forward|detach|go|visit => $notfound_action_name },
        error => { forward|detach|go|visit => $error_action_name },
    }

Globalizing the 'error' and 'notfound' action handlers is probably the most 
useful.  Each option key within 'handlers' canonically takes a hashref, where
the key is either 'forward' or 'detach' and the value is the name of something we
can call "$ctx->forward" or "$ctx->detach" on.  We coerce from a string value
into a hashref where 'forward' is the key (unless 'detach_exceptions' is true).
If youd actually set the key value, that value is used no matter what the state
of L</detach_exceptions>.

=head2 check_args_pattern 

Before sending any incoming arguments from the action to your model's find
condition, we test each argument through a regular expression.  Although
L<DBIx::Class> is pretty smart with arguments (there are no inline variable
interpolation in the generated SQL, everything uses bind variables) arguments
do come from client browers and as such cannot be trusted.  By default the
regular expression used to test arguments is:

    qr/^[\w\.,`~!@#$\%^&*\(\)_\-=+]{1,96}$/ 

Basically this is a pretty forgiving filter, designed in mind with the types of
primary keys or other unique data we've seen.  We had the following types in mind:

    Integer - 21412343
    UUID - 995cd3c4-62a6-11df-a00c-7d9949bad02a 
    Email - "johnn@shutterstock.com"
    Phone Numbers - (212)387-1111 | 011-86-9106-26059
    USA Social Security (although you know not to use this right?) - 005-82-1111


The primary limit is on the length of the incoming argument, which will be cut 
off at 96 characters.  This large size is to allow for the email pattern.  If
you wish for something more restrictive, you can write your own.  This filter
should allow nearly all the most standard unique keys, such as integer, uuids,
email addresses, etc, while placing sometype of limit on the size and permitted
characters so that this doesn't become an attack vector on your database.

If the incoming argument fails to match the regular expression, we immediately
delegate to the ERROR handler.  Since we don't perform any cleaning on the 
arguments, some care should be taken on your side to properly exscape and
untaint any args used in error messages, in your logs, etc.

=head1 METHODS

This role defines the follow methods which subclasses may wish to override.

=head2 _check_arg ($arg)

tests an incoming $args against the L<check_args_pattern> described above.  
Returns a boolean.  We consider this method of internal value only.

=head1 FIND CONDITION DETAILS

This section adds details regarding what a find condition is ond provides some
examples.

=head2 defining a find condition

A find condition is the definition of something unique we can match and return
a single row or result.  Basically this is anything you'd pass to the 'find'
method of L<DBIx::Class::ResultSet>.

Canonically a find_condition is an ArrayRef of key limited HashRefs, but we 
coerce from some common cases to make things a bit easier.  Examples follow.

By default we automatically handle the most common case, where a single argument
maps to a single column primary key field.  In every other case, such as when
you have multi field primary keys or you are finding by an alternative unique
constraint (either single or multi fields) you need to declare the name of the
L<DBIx::Class::ResultSource> unique constraint you are matching against.  Since
L<DBIx::Class> does not require you to name your unique constraints (many people
let the underlying database follow its default convention in this matter),
instead of a unique constraint name you may pass an ArrayRef of one or more
columns which together define a uniqiue nstraint.  Please note if you use this
form of defining a find condition, you must use an ArrayRef EVEN if your condition
has only a single column.

Also note that in the case of multi field primary keys or unique constraints,
we attempt to match against the field order as defined in your call to
L<DBIx::Class::ResultSource/primary_columns> or
L<DBIx::Class::ResultSource/add_unique_constraint>.

If you need to to specify the mapping of L<Catalyst> arguments to unique
constraint fields, please see 'match_order' options.
    
=head2 example find conditions

Find where one arg is mapped to a single field primary key (default case).

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => 'Schema::User',
                find_condition => 'primary',
            }
        }
    );

BTW, the above would internally 'canonicalize' the find_condition to:

    find_condition => [{
        constraint_name=>'primary',
        columns=>['user_id'], 
        match_order=>['user_id'],
    }],

Same as above but the find condition can be any of several named constraints, 
all of which have the same number of fields.  In this case we'd expect the 
underlying User ResultSource to define a primary key and a unique constraint
named 'unique_email'.

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => 'Schema::User',
                find_condition => ['primary', 'unique_email'],
            }
        }
    );

Same as above, but the unique email constraint was not named so we need to map
some fields to a unique constraint.  Please note we actually look for a unique
constraint using the named columns, failed matches throw an expection.

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => 'Schema::User',
                find_condition =>  ['primary', {columns=>['email']}],
            }
        }
    );

An example where the find condition is a mult key unique constraint.

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => 'Schema::User',
                find_condition =>  {columns=>['user_id','role_id']},
            }
        }
    );

As above but lets you specify an argument to field order mapping which is
different from that defined in your L<DBIx::Class::ResultSource>.  This let's
you decouple your L<Catalyst> action arg definition from your L<DBIx::Class::ResultSource>
definition.

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => 'Schema::User',
                find_condition =>  {
                    columns=>['user_id','role_id'],
                    match_order=>['role_id','user_id'],
                },
            }
        }
    );

This last would internally canonicalize to:

    __PACKAGE__->config(
        action_args => {
            photo => {
                store => {model => 'Schema::User'},
                find_condition =>  [{
                    constraint_name=>'fk_user_id_fk_role_id',
                    columns=>['user_id','role_id'],
                    match_order=>['role_id','user_id'],
                }],
            }
        }
    );

Please note the 'constraint_name' in this case is provided by the underlying
storage, the value given is a reasonable guess.

=head2 subroutine handlers versus action handlers

Based on the result of the find condition we try to invoke methods or actions
in the containing controller, based on a naming convention.  By default we first
try to invoke an action based on the template $action."_".$result

=head1 NOTES

The following section is additional notes regarding usage or questioned related
to this action role.

=head2 Why an Action Role and not an Action Class?

Role are more flexible, you can combine many roles easily to compose flexible
behavior in an elegant way.  This does of course mean that you will need a
more modern L<Catalyst> based on L<Moose>.

=head2 Why require such a modern L<Catalyst>?

We need a version of L<Catalyst that is post the L<Moose> migration; additionally
we need equal to or greater than version '5.80019' for the ability to define 
'action_args' in a controller.  See L<Catalyst::Controller> for more.

=head1 AUTHOR

John Napiorkowski <jjnapiork@cpan.org>

=head1 COPYRIGHT & LICENSE

Copyright 2010, John Napiorkowski <jjnapiork@cpan.org>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

