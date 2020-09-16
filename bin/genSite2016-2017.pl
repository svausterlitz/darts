#!/usr/bin/env perl

use v5.018;
use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
binmode STDIN,  ":encoding(UTF-8)";

use Data::Printer;
use DateTime;
use Excel::Writer::XLSX;
use File::Path::Expand;
use File::Spec;
use FindBin;
use Getopt::Long;
use HTML::Table;
use Spreadsheet::XLSX;
use Template;
use Time::Piece;
use WWW::Mechanize;
use YAML 'LoadFile';

use lib "$FindBin::Bin/../lib";

use DS::Match;
use DS::Player;

use experimental 'signatures';
no warnings "experimental::signatures";

my $options = { file => '', updatesite => 0 };
GetOptions(
    "file=s"     => \$options->{file},
    "updatesite" => \$options->{updatesite},
);

die unless ( $options->{file} );

my $config = LoadFile(expand_filename('~/.darts.yaml'));
my $file   = File::Spec->rel2abs( $options->{file} );
my $excel  = Spreadsheet::XLSX->new($file);

my $playerslookup = {};
my @matches;
my @players;
my $date;

my $lastdate;
foreach my $sheet ( @{ $excel->{Worksheet} } ) {

    my $sheet_name = $sheet->{Name};
    my $i          = 0;
    my %names      = map { $_->{Val} => $i++ } @{ $sheet->{Cells}->[0] };
    if ( $sheet_name =~ /^koppel/i ) {
        #koppeltabel
        $date = $sheet->{Name} =~ s/^koppel.*\s+//ri; #/
	say($date);

        # p $date;

        foreach my $row ( 1 .. $sheet->{MaxRow} ) {
            my $player = getPlayer(
                $sheet->{Cells}->[$row]->[ $names{Speler} ]->{Val} );
            $player->{score}
                += $sheet->{Cells}->[$row]->[ $names{Points} ]->{Val} // 0;
            $player->{matchcount}
                += $sheet->{Cells}->[$row]->[ $names{Matches} ]->{Val} // 0;
            $player->{lollies}
                += $sheet->{Cells}->[$row]->[ $names{Lollies} ]->{Val} // 0;
            $player->{max} += $sheet->{Cells}->[$row]->[ $names{Max} ]->{Val}
                // 0;
            push @{ $player->{finishes} }, split ',',
                $sheet->{Cells}->[$row]->[ $names{Finishes} ]->{Val} // '';
        }
    }
    else {

        $date = $sheet->{Name};
        foreach my $row ( 1 .. $sheet->{MaxRow} ) {
            my $matchdata = {
                date  => $date,
                baan  => $sheet->{Cells}->[$row]->[ $names{Baan} ]->{Val},
                ronde => $sheet->{Cells}->[$row]->[ $names{Ronde} ]->{Val},
                speler1 =>
                    $sheet->{Cells}->[$row]->[ $names{Speler1} ]->{Val},
                speler2 =>
                    $sheet->{Cells}->[$row]->[ $names{Speler2} ]->{Val},
                legs1 => $sheet->{Cells}->[$row]->[ $names{Legs1} ]->{Val},
                legs2 => $sheet->{Cells}->[$row]->[ $names{Legs2} ]->{Val},
                lollies1 =>
                    $sheet->{Cells}->[$row]->[ $names{Lollies1} ]->{Val} // 0,
                lollies2 =>
                    $sheet->{Cells}->[$row]->[ $names{Lollies2} ]->{Val} // 0,
                max1 => $sheet->{Cells}->[$row]->[ $names{Max1} ]->{Val} || 0,
                max2 => $sheet->{Cells}->[$row]->[ $names{Max2} ]->{Val} || 0,
                finishes1 => [
                    split ',',
                    $sheet->{Cells}->[$row]->[ $names{Finishes1} ]->{Val}
                        // ''
                ],
                finishes2 => [
                    split ',',
                    $sheet->{Cells}->[$row]->[ $names{Finishes2} ]->{Val}
                        // ''
                ],
            };

            $matchdata->{player1} = getPlayer( $matchdata->{speler1} );
            $matchdata->{player2} = getPlayer( $matchdata->{speler2} );

            push @matches, $matchdata;

        }

	#	say "bla: $date";
    }

    $lastdate = $date;
    

}

say($lastdate);

my $now = DateTime->now(
    time_zone => DateTime::TimeZone->new( name => 'local' ) );
my $updatetime = $now->dmy . ' ' . $now->hms;
my $updateuntil = Time::Piece->strptime( $lastdate, "%Y-%m-%d" )->dmy;

foreach my $matchdata (@matches) {
    parsePlayer( 1, $matchdata );
    parsePlayer( 2, $matchdata );
}

unlink("/tmp/standen_$lastdate.xlsx");
my $workbook = Excel::Writer::XLSX->new("/tmp/standen_$lastdate.xlsx");

my %tables;

# p @players;

my @players_stand
    = sort { $a->{matchcount} <=> $b->{matchcount} } @players;
@players_stand = sort { $b->{score} <=> $a->{score} } @players_stand;

{
    my @table = (
        [   'Stand',     'Naam', 'Punten',        'Wedstrijden',
            'Gemiddeld', '180',  '100+ finishes', 'lollies'
        ]
    );
    my $i = 1;
    foreach my $player (@players_stand) {
        my $print_i = $i;
        if ( $player->{score} eq $table[-1]->[2] ) {
            $print_i = ' ';
        }

        my @row = (
            $print_i,
            $player->{name},
            $player->{score},
            $player->{matchcount},
            $player->{matchcount}
            ? sprintf( "%0.2f", $player->{score} / $player->{matchcount} )
            : 0,
            $player->{max},
            join( ', ', @{ $player->{finishes} } ) || ' ',
            $player->{lollies},
        );
        push @table, \@row;
        $i++;
    }

    my $worksheet = storeTable( 'alles', \@table );
    my $format = $workbook->add_format( align => 'center', bottom => 1 );

    $worksheet->set_column( 0, 0, undef, $format );
    $worksheet->set_column( 1, 1, 12,    $format );
    $worksheet->set_column( 2, 2, undef, $format );
    $worksheet->set_column( 3, 3, 12,    $format );
    $worksheet->set_column( 4, 4, 12,    $format );
    $worksheet->set_column( 5, 5, undef, $format );
    $worksheet->set_column( 6, 6, 30,    $format );
    $worksheet->set_column( 7, 7, undef, $format );

    $worksheet->set_paper(9);
    $worksheet->set_margins(0.1);
    $worksheet->center_horizontally();
    $worksheet->set_landscape();
}

{
    my @table
        = ( [ 'Stand', 'Naam', 'Punten', 'Wedstrijden', 'Gemiddeld', ] );
    my $i = 1;
    foreach my $player (@players_stand) {
        my $print_i = $i;
        if ( $player->{score} eq $table[-1]->[2] ) {
            $print_i = '';
        }

        my @row = (
            $print_i,
            $player->{name},
            $player->{score},
            $player->{matchcount},
            $player->{matchcount}
            ? sprintf( "%0.2f", $player->{score} / $player->{matchcount} )
            : 0,
        );

        push @table, \@row;
        $i++;
    }

    my $worksheet = storeTable( 'stand', \@table );
}

my @players_180
    = sort { $b->{max} <=> $a->{max} } grep { $_->{max} } @players;
{
    my @table = ( [ 'Naam', 'x 180' ] );
    foreach my $player (@players_180) {
        my @row = ( $player->{name}, $player->{max}, );
        push @table, \@row;
    }

    my $worksheet = storeTable( '180', \@table );

}

my @players_finishes = sort { $b->{finishes}->[0] <=> $a->{finishes}->[0] }
    grep { @{ $_->{finishes} } } @players;
{
    my @table = ( [ 'Naam', 'Finishes 100+', ] );
    foreach my $player (@players_finishes) {
        my @row = ( $player->{name}, join( ', ', @{ $player->{finishes} } ) );
        push @table, \@row;
    }

    my $worksheet = storeTable( 'finishes', \@table );
}

my @players_lollies = sort { $b->{lollies} <=> $a->{lollies} }
    grep { $_->{lollies} } @players;
{
    my @table = ( [ 'Naam', 'Lollies', ] );
    foreach my $player (@players_lollies) {
        my @row = ( $player->{name}, $player->{lollies}, );
        push @table, \@row;
    }

    my $worksheet = storeTable( 'lollies', \@table );
}

$workbook->close();

my $mech;
if ( $options->{updatesite} ) {
    $mech = WWW::Mechanize->new(autocheck => 0, ssl_opts => { verify_hostname => 0 });
    $mech->get('https://svausterlitz.voetbalassist.nl/cms/index.aspx');
    my $res = $mech->submit_form(
        form_name => 'aspnetForm',
        fields    => {
            'ctl00$Content$GebruikersnaamTb' => $config->{website}->{username},
            'ctl00$Content$wachtwoord'     => $config->{website}->{password},
        },
        button => 'ctl00$Content$SubmitBtn'
    );

    if ( $res->is_success ) {
        updatePage('stand');
        updatePage(180);
        updatePage('finishes');
        updatePage('lollies');
    }

}

exit;

sub updatePage {
    my $name = shift;

    my $aoa = $tables{$name};

    my $pages = {
        stand => {
            title => 'Competitiestand',
            uri =>
                'https://svausterlitz.voetbalassist.nl/cms/Index2.aspx?m=1&o=1&miid=412',
        },
        180 => {
            title => "Aantal 180's",
            uri =>
                'https://svausterlitz.voetbalassist.nl/cms/Index2.aspx?m=1&o=1&miid=413',
        },
        finishes => {
            title => 'Hoogste finishes',
            uri =>
                'https://svausterlitz.voetbalassist.nl/cms/Index2.aspx?m=1&o=1&miid=414',
        },
        lollies => {
            title => 'Aantal Lollies',
            uri =>
                'https://svausterlitz.voetbalassist.nl/cms/Index2.aspx?m=1&o=1&miid=493',
        },
    };

    my $table = HTML::Table->new($aoa);
    $table->setBorder(1);
    my $t = $table->getTable;

    my $content
        = "<h1>$pages->{$name}->{title}</h1>"
        . "<h3>Bijgewerkt t/m $updateuntil</h3>"
        . '<p>Voor veel meer details: <a href="https://svausterlitz.github.io/darts/seizoen.html?seizoen=Austerlitz_seizoen_2020-2021">gedetailleerd overzicht</a></p>'
        . $table
        . '<p><hr>'
        . 'updated '
        . $updatetime;

    $mech->get( $pages->{$name}->{uri} );
    my $res = $mech->submit_form(
        form_name => 'aspnetForm',
        fields    => {
            'Mp$Content$ctl00$contentTextBox' => $content,
            'Mp$Content$ctl00$Opslaan'        => 'Opslaan',
        },
        button => 'Mp$Content$ctl00$Opslaan'
    );
}

sub storeTable {
    my $name  = shift;
    my $table = shift;

    $tables{$name} = $table;
    my $worksheet = $workbook->add_worksheet($name);
    $worksheet->write_col( 1, 0, $table );

    my $format
        = $workbook->add_format( valign => 'vcenter', align => 'center', );
    $worksheet->merge_range( 0, 0, 0, 7, "Bijgewerkt t/m $updateuntil",
        $format );
    return $worksheet;
}

sub getPlayer {
    my $name   = shift;
    my $player = $playerslookup->{$name};
    if ( !$player ) {
        $player = DS::Player->new( { name => $name } );
        $playerslookup->{$name} = $player;
        push @players, $player;
    }

    return $player;
}

sub parsePlayer {
    my $nr        = shift;
    my $matchdata = shift;

    my $own = $nr;
    my $other = abs( 1 - $nr ) || 2;

    my $player = $matchdata->{"player$own"};
    $player->{matchcount}++;

    if ( $matchdata->{"legs$own"} == 2 && $matchdata->{"legs$other"} == 0 ) {
        $player->{score} += 5;
    }
    elsif ( $matchdata->{"legs$own"} == 2 && $matchdata->{"legs$other"} == 1 )
    {
        $player->{score} += 3;
    }
    elsif ( $matchdata->{"legs$own"} == 1 && $matchdata->{"legs$other"} == 2 )
    {
        $player->{score} += 1;
    }

    if ( my $max = $matchdata->{"max$own"} ) {
        $player->{max} += $max;

        #elke 180 is extra punt
        $player->{score} += $max;
    }

    if ( my $lollies = $matchdata->{"lollies$own"} ) {
        $player->{lollies} += $lollies;
    }

    for my $finish ( @{ $matchdata->{"finishes$own"} } ) {
        push @{ $player->{finishes} }, $finish;
        @{ $player->{finishes} }
            = sort { $b <=> $a } @{ $player->{finishes} };

        if ( $finish >= 100 && $finish <= 110 ) {
            $player->{score} += 1;
        }
        elsif ( $finish >= 111 && $finish <= 120 ) {
            $player->{score} += 2;
        }
        elsif ( $finish >= 121 && $finish <= 130 ) {
            $player->{score} += 3;
        }
        elsif ( $finish >= 131 && $finish <= 140 ) {
            $player->{score} += 4;
        }
        elsif ( $finish >= 141 && $finish <= 150 ) {
            $player->{score} += 5;
        }
        elsif ( $finish >= 151 && $finish <= 158 ) {
            $player->{score} += 6;
        }
        elsif ( $finish >= 160 && $finish <= 167 ) {
            $player->{score} += 7;
        }
        elsif ( $finish == 170 ) {
            $player->{score} += 10;
        }
    }
}

