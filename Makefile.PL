#!/usr/bin/env perl

use strict;
use warnings;
use inc::Module::Install;

requires (
    'Moose' => '1.07',
    'MooseX::Types' => '0.22',
    'Catalyst::Runtime' => '5.80024',
    'Perl6::Junction' => '1.40000',
    'Catalyst::Controller::ActionRole' => '0',
    'Try::Tiny' => '0',
);

build_requires (
    'Test::More' => '0.94',
    'DBIx::Class' => '0.08121',
    'Catalyst::Runtime' => '5.80024 ',
    'Catalyst::Model::DBIC::Schema' => '0.41',
    'Catalyst::Controller::ActionRole' => '0',
);

all_from 'lib/Catalyst/ActionRole/BuildDBICResult.pm';
auto_install;
WriteAll;

