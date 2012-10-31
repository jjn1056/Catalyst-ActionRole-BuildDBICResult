#!/usr/bin/env perl

use strict;
use warnings;
use inc::Module::Install;

repository 'git://github.com/jjn1056/Catalyst-ActionRole-BuildDBICResult.git';

requires (
    'Moose' => '1.10',
    'MooseX::Types' => '0.23',
    'Perl6::Junction' => '1.40000',
    'Try::Tiny' => '0.06',
);

build_requires (
    'Test::More' => '0.94',
    'DBIx::Class' => '0.08203',
    'Catalyst::Runtime' => '5.90018',
    'Catalyst::Model::DBIC::Schema' => '0.43',
);

all_from 'lib/Catalyst/ActionRole/BuildDBICResult.pm';
auto_install;
WriteAll;

