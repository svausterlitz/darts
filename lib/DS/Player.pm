package DS::Player;

use v5.020;
use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
binmode STDIN,  ":encoding(UTF-8)";

use Data::Printer;

use parent ('Class::Accessor');

use experimental 'signatures';
no warnings "experimental::signatures";

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( 'name' );

sub new($class, $args) {
    my $self = $class->SUPER::new($args);

    $self->{finishes}   = [];
    $self->{lollies}    = 0;
    $self->{matchcount} = 0;
    $self->{max}        = 0;
    $self->{score}      = 0;

    return $self;

}

1;
