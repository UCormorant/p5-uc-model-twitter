#!/usr/local/bin/perl

use 5.014;
use lib::Utils;
use autodie;

use Uc::Model::Twitter;
use AnyEvent::Twitter::Stream;
use Getopt::Long;
use Config::Pit;

local $| = 1;
$ENV{ANYEVENT_TWITTER_STREAM_SSL} = 1;

my ( $driver, $database, $create_table, $if_not_exists, $help ) = ('') x 5;
my $result = GetOptions(
    "d|driver=s"      => \$driver,
    "db|database=s"  => \$database,
    "c|create-table" => \$create_table,
    "if-not-exists"  => \$if_not_exists,
    "h|help|?"       => \$help,
);
$driver        ||= 'sqlite';
$if_not_exists ||= 0;

say <<"_HELP_" and exit if scalar(@ARGV) < 2;
Usage: $0 -db ./twitter.db username password
    -d  --driver:        DBI Driver. SQLite or mysql. default driver is 'SQLite'.
    -db --database:      Database name. if it is not set, SQLite uses ':memory:' and mysql uses 'test'.
    -c  --create-table:  exec DROP TABLE; CREATE TABLE.
        --if-not-exists: exec CREATE TABLE IF NOT EXISTS when it is set with -c option.
_HELP_

$SIG{INT} = $SIG{TERM} = $SIG{BREAK} = sub { exit; };
$SIG{__DIE__} = sub { logging(); };
END { logging(); }

my $db_user = '';
my $db_pass = '';
if ($driver eq 'mysql') {
    my $mysql_conf = pit_get($driver, require => {
        user => '',
        pass => '',
    });
    $db_user = $mysql_conf->{user};
    $db_pass = $mysql_conf->{pass};
}
my $schema = Uc::Model::Twitter->new( dbh => setup_dbh($driver, $database, $db_user, $db_pass) );
my @tweets;

main();
exit;


sub main {
    my $cv = AE::cv;
    my $spacer = 0;

    if ($create_table) {
        print "create table... ";
        $schema->create_table( if_not_exists => $if_not_exists );
        say "done.";
    }

    print "streamer starts to read... ";
    my $interval;
    my $streamer = AnyEvent::Twitter::Stream->new(
        username => $ARGV[0],
        password => $ARGV[1],
        method   => 'sample',

        on_connect => sub {
            say "connected.";
            $interval = AE::timer 0, 10, sub { logging() };
        },
        on_tweet => sub {
            my $tweet = shift;
            if (!$tweet->{user} or $tweet->{text} eq '') { return; }
            my $len = length $tweet->{user}{screen_name};
            $spacer = $len if $len > $spacer;
            say sprintf "%${spacer}s: %s", $tweet->{user}{screen_name}, $tweet->{text};

            push @tweets, $tweet;
            logging() if scalar @tweets == 20;
#            $schema->find_or_create_status_from_tweet($tweet);
        },
        on_event => {},
        on_error => sub {
            warn "error: $_[0]";
            undef $interval;
            $cv->send;
        },
        on_eof => $cv,
    );

    $cv->recv;
}

sub logging {
    if (scalar @tweets) {
        my $txn = $schema->txn_scope;
        $schema->find_or_create_status_from_tweet(shift @tweets) while @tweets;
        $txn->commit;
    }
}

1;
