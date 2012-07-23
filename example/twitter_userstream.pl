#!perl

use 5.010;
use common::sense;
use warnings qw(utf8);

use Readonly;
Readonly my $CHARSET => 'cp932';
binmode STDIN  => ":encoding($CHARSET)";
binmode STDOUT => ":encoding($CHARSET)";
binmode STDERR => ":encoding($CHARSET)";

use lib qw(lib ../lib);
use Uc::Twitter::Schema;
use Encode qw(find_encoding);
#use Encode::Guess qw(euc-jp shiftjis 7bit-jis); # using 'guess_encoding' is recoomended
use AnyEvent::Twitter::Stream;
use Config::Pit;
use Getopt::Long;
use IO::File;

require "twitter_agent.pl";
require "profile_id.pl";

use Data::Dumper;

BEGIN { $ENV{ANYEVENT_TWITTER_STREAM_SSL} = 1 }
local $Data::Dumper::Indent = 0;

my ( $debug, $help ) = ('') x 2;
my $result = GetOptions(
    "d|debug" => \$debug,
    "h|help|?" => \$help,
);

warn <<"_HELP_" and exit if scalar(@ARGV) < 1;
Usage: $0 [-d debug] (conf_name)
_HELP_

my $prof = shift;
my $utig = pit_get('utig.pl', require => {
    consumer_key    => '',
    consumer_secret => '',
});
my $mysql = pit_get('mysql', require => {
    user => '',
    pass => '',
});
my $config = pit_get("utig.pl.$prof");
my $nt = twitter_agent($utig, $config);
pit_set("utig.pl.$prof", data => $config) if $nt->{config_updated};
my $encode = find_encoding($CHARSET);
my $schema = Uc::Twitter::Schema->connect('dbi:mysql:twitter', $mysql->{user}, $mysql->{pass}, {
#    RaiseError        => 1,
    mysql_enable_utf8 => 1,
    on_connect_do     => ['set names utf8', 'set character set utf8'],
});
$schema->storage->debug($debug);
$schema->storage->debugfh(IO::File->new('./twitter_userstream.out', 'w'));

my $cv = AE::cv;

my @tweet;
my $interval;
my $streamer = AnyEvent::Twitter::Stream->new(
    consumer_key    => $utig->{consumer_key},
    consumer_secret => $utig->{consumer_secret},
    token           => $config->{token},
    token_secret    => $config->{token_secret},
    method          => 'userstream',

    on_connect => sub {
        say "connect.";
        $interval = AE::timer 0, 10, sub { save_tweet() };
    },
    on_friends => sub {
        say Dumper(shift);
    },
    on_tweet => sub {
        my $t = shift;
        if (!$t->{user} or !$t->{text}) { warn Dumper($t); return; }
        say "$t->{user}{screen_name}: $t->{text}";

        push @tweet, $t;
        save_tweet() if scalar @tweet >= 10;
    },
    on_error => sub {
        warn "error: $_[0]";
        undef $interval;
        $cv->send;
    },
    on_eof => $cv,
);

sub save_tweet {
    if (scalar @tweet) {
        $schema->txn_do(sub {
            while (@tweet) {
                $schema->resultset('Status')->find_or_create_from_tweet(
                    shift @tweet,
                    { user_id => $config->{user_id}, ignore_remark_disabling => 1 }
                );
            }
        });
    }
}

$SIG{INT} = $SIG{TERM} = $SIG{BREAK} = sub { exit; };
$SIG{DIE} = sub { save_tweet(); };
END { save_tweet(); }

$cv->recv;
