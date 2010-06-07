package # hide from PAUSE
  TestApp::Controller::Inherit;

use Moose;
use namespace::autoclean;

BEGIN {
    extends 'Catalyst::Controller';
}

__PACKAGE__->config(
    action_args => {
        'store_as_str' => {
            store => 'User',
        },
        'find_cond_as_str' => {
            find_condition => 'unique_email',
        },
        'find_cond_as_cond' => {
            find_condition => {
                constraint_name => 'social_security',
            },
        },
        'find_cond_as_cond2' => {
            find_condition => {
                columns => ['id'],
            },
        },
        'user_default' => {
            store => 'Schema::User',
            find_condition => [ 'primary', ['email'] ],
        },
        'user_detach_error' => {
            store => 'Schema::User',
            find_condition => [ 'primary', ['email'] ],
            auto_stash => 'user',
            handlers => {
                error => {detach => 'local_error'},
                notfound => {detach => 'local_notfound'},
            },
        },
        'user_method_store' => {
            store => {method => 'user_rs' },
            find_condition => [ 'primary', ['email'] ],
            auto_stash => 'user',
        },
    },
);

has user_rs => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_user_rs {
    my $self = shift @_;
    return $self->_app->model('Schema::User');
}

sub defaults
  :Path('defaults') 
  :ActionClass('+TestApp::Action::BuildDBICResult') {}

sub store_as_str
  :Path('store_as_str') 
  :ActionClass('+TestApp::Action::BuildDBICResult') {}

sub find_cond_as_str
  :Path('find_cond_as_str') 
  :ActionClass('+TestApp::Action::BuildDBICResult') {}

sub find_cond_as_cond
  :Path('find_cond_as_cond') 
  :ActionClass('+TestApp::Action::BuildDBICResult') {}

sub find_cond_as_cond2
  :Path('find_cond_as_cond2') 
  :ActionClass('+TestApp::Action::BuildDBICResult') {}


sub user_default
  :ActionClass('+TestApp::Action::BuildDBICResult')
  :Path('user_default')
  :Args(1)
{
    my ($self, $ctx, $id) = @_;
    push @{$ctx->stash->{res}}, 'user_default';
}

    sub user_default_FOUND :Action {
        my ($self, $ctx, $user, $id) = @_;
        push @{$ctx->stash->{res}}, $user->email;
    }

    sub user_default_NOTFOUND :Action {
        my ($self, $ctx, $user, $id) = @_;
        push @{$ctx->stash->{res}}, 'notfound';
    }

    sub user_default_ERROR :Action {
        my ($self, $ctx, $err, $id) = @_;
        ($err) = ($err=~m/^(.+?)\!/); 
        push @{$ctx->stash->{res}}, 'error', $err;
    }

sub user_detach_error
  :ActionClass('+TestApp::Action::BuildDBICResult')
  :Path('user_detach_error')
  :Args(1)
{
    my ($self, $ctx, $id) = @_;
    push @{$ctx->stash->{res}}, 'user_detach_error';
}

    sub local_notfound :Private {
        my ($self, $ctx) = @_;
        push @{$ctx->stash->{res}}, 'local_notfound';
    }

sub user_method_store 
  :ActionClass('+TestApp::Action::BuildDBICResult')
  :Path('user_method_store')
  :Args(1)
{
    my ($self, $ctx, $id) = @_;
    push @{$ctx->stash->{res}}, 'user_method_store';
}

sub end :Private {
    my ($self, $ctx) = @_;
    if(my $user = $ctx->stash->{user}) {
        my $email = $user->email;
        push @{$ctx->stash->{res}}, $email;
    }

    if(my $res = $ctx->stash->{res}) {
        $ctx->res->body(join(',', @$res));
    }
}


1;
