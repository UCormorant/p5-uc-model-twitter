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

my $streamer = AnyEvent::Twitter::Stream->new(
    consumer_key    => $utig->{consumer_key},
    consumer_secret => $utig->{consumer_secret},
    token           => $config->{token},
    token_secret    => $config->{token_secret},
    method          => 'userstream',


    on_connect => sub {
        say "connect.";
    },
    on_tweet => sub {
    },
    on_event => sub {
        my $event = shift;
        my $happen = $event->{event};
        my $source = $event->{source}{screen_name};
        my $target = $event->{target}{screen_name};
        my $object = $event->{target_object};
        say "$happen: $source to $target: ".Dumper($object);
    },
    on_error => sub {
        warn "error: $_[0]";
        $cv->send;
    },
    on_eof => $cv,
);

$cv->recv;
