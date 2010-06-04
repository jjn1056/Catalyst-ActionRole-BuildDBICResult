package # Hide from PAUSE
  TestApp::DBIC::ResultSet::User;

use strict;
use warnings;

use base 'TestApp::DBIC::ResultSet';

sub find {
    my $self = shift @_;
    my $result = $self->next::method(@_);
    if($result) {
        die 'BOO!' if $result->id == 104;
    }
    return $result;
}


1;
