package lib::Utils;

use 5.012;
use warnings;
use utf8;
use autodie;
use Encode qw(find_encoding);
#use Encode::Guess qw(euc-jp shiftjis 7bit-jis); # using 'guess_encoding' is recoomended
use AnyEvent::Twitter::Stream;
use Data::Dumper;

our @EXPORT = qw(codec setup_dbh sample_stream Dumper);

local $Data::Dumper::Indent = 0;

use Readonly;
Readonly my $CHARSET => ($^O eq 'MSWin32' ? 'cp932' : 'utf8');
binmode STDIN  => ":encoding($CHARSET)";
binmode STDOUT => ":encoding($CHARSET)";

sub import {
    no strict 'refs';

    my $class = shift;
    my $pkg = caller;
    strict->import;
    warnings->import;
    utf8->import;

    my %EXPORT_OK = map { ($_, 1) } @EXPORT;
    *{$pkg.'::'.$_} = *{$_} for scalar @_ ? grep { $EXPORT_OK{$_} } @_ : @EXPORT;
}

our %codec;
sub codec {
    my $charset = shift // $CHARSET;
    $codec{$charset} ? $codec{$charset} : find_encoding($charset);
}

sub setup_dbh {
    given (lc shift) {
        when ('sqlite') { return setup_dbh_sqlite(@_);  }
        when ('mysql')  { return setup_dbh_mysql(@_);   }
        default         { die "'$_' is not supported."; }
    }
}

sub setup_dbh_sqlite {
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,'','',{RaiseError => 1, PrintError => 0, AutoCommit => 1, sqlite_unicode => 1});
}

sub setup_dbh_mysql {
    my $db = shift || 'test';
    my $user = shift;
    my $pass = shift;
    DBI->connect('dbi:mysql:'.$db,$user,$pass,{RaiseError => 1, PrintError => 0, AutoCommit => 1,  mysql_enable_utf8 => 1});
}

sub sample_stream {
    my ($user, $pass, $count) = @_;
    my @tweets;
    $count = 100 if $count < 1;
    print "streamer starts to read... ";

    my $cv = AE::cv;
    my $streamer = AnyEvent::Twitter::Stream->new(
        username => $user,
        password => $pass,
        method   => 'sample',

        on_connect => sub {
            say "connected.";
            print "collect $count tweets... ";
        },
        on_tweet => sub {
            my $tweet = shift;
            if (!$tweet->{user} or $tweet->{text} eq '') { return; }
            push @tweets, $tweet;
            $cv->send if scalar @tweets == $count;
        },
        on_event => {},
        on_error => sub {
            die "error: $_[0]";
        },
        on_eof => $cv,
    );
    $cv->recv;

    say "done.";
    return \@tweets;
}

1;
