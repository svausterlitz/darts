package DS::Match;

use v5.020;
use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
binmode STDIN,  ":encoding(UTF-8)";

use Data::Printer;
use Math::Round 'round';

use parent ('Class::Accessor');

use experimental 'signatures';
no warnings "experimental::signatures";

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( 'date', 'round', 'player1', 'player2', 'score1',
    'score2', 'seq' );

my $factor = 400;
my $K      = 32;

sub new($class, $args) {
    my $self = $class->SUPER::new($args);

    $self->{date}  //= $self->{datum};
    $self->{round} //= $self->{ronde};
    $self->{seq} = $self->{date} . ' ' . sprintf( '%02i', $self->{round} );

    return $self;

}

sub calcratings($self) {
    $self->{player1}->addMatch($self);
    $self->{player2}->addMatch($self);

    my $p1_score = $self->{score1} / ( $self->{score1} + $self->{score2} );
    my $p2_score = $self->{score2} / ( $self->{score1} + $self->{score2} );
    my $p1_rating = $self->{player1}->get_rating;
    my $p2_rating = $self->{player2}->get_rating;

    my $E1 = 1 / ( 1 + 10**( ( $p2_rating - $p1_rating ) / $factor ) );
    my $E2 = 1 / ( 1 + 10**( ( $p1_rating - $p2_rating ) / $factor ) );
    my $p1_mutation = round($K * ( $p1_score - $E1 ));
    my $p2_mutation = round($K * ( $p2_score - $E2 ));

    $self->{player1}->addMutation($p1_mutation);
    $self->{player2}->addMutation($p2_mutation);
}

1;
