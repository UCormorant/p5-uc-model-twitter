#!/usr/bin/env perl

use 5.014;
use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catdir);
use lib catdir(dirname(__FILE__));
use lib catdir(dirname(__FILE__), '..', 'lib');

use lib::Util;
use Uc::Model::Twitter;

use autodie;
use Getopt::Long;
use Config::Pit;

use AnyEvent::Twitter::Stream;

local $| = 1;

$ENV{ANYEVENT_TWITTER_STREAM_SSL} = 1;

my ( $driver, $database, $create_table, $if_not_exists, $force_create, $help ) = ('') x 6;
my $result = GetOptions(
    "d|driver=s"      => \$driver,
    "db|database=s"  => \$database,
    "c|create-table" => \$create_table,
    "force-create"   => \$if_not_exists,
    "h|help|?"       => \$help,
);
$driver        ||= 'sqlite';
$if_not_exists = $force_create ? 0 : 1;

say <<"_HELP_" and exit if $help;
Usage: $0 -db ./twitter.db
    -d  --driver:        DBI Driver. SQLite or mysql. default driver is 'SQLite'.
    -db --database:      Database name. if it is not set, SQLite uses ':memory:' and mysql uses 'test'.
    -c  --create-table:  exec CREATE TABLE IF NOT EXISTS.
        --force-create:  exec CREATE TABLE without 'IF NOT EXISTS' when it is set with -c option.
_HELP_

$SIG{INT} = $SIG{TERM} = $SIG{BREAK} = sub { exit; };
$SIG{__DIE__} = sub { logging(); };
END { logging(); }

my $db_user = '';
my $db_pass = '';
if ($driver eq 'mysql' && $database) {
    my $mysql_conf = pit_get($driver, require => {
        user => 'mysql database user',
        pass => 'mysql user password',
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

    my $conf_app  = pit_get('dev.twitter.com', require =>{
        consumer_key    => 'your twitter consumer_key',
        consumer_secret => 'your twitter consumer_secret',
    });
    my $conf_user = +{};
    twitter_agent($conf_app, $conf_user);

    print "streamer starts to read... ";
    my $interval;
    my $streamer = AnyEvent::Twitter::Stream->new(
        method          => 'sample',
        consumer_key    => $conf_app->{consumer_key},
        consumer_secret => $conf_app->{consumer_secret},
        token           => $conf_user->{token},
        token_secret    => $conf_user->{token_secret},

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
#            $schema->find_or_create_status($tweet);
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
        $schema->find_or_create_status(shift @tweets) while @tweets;
        $txn->commit;
    }
}
