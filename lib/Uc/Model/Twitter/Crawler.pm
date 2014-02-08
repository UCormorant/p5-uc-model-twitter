package Uc::Model::Twitter::Crawler;

use 5.014;
use warnings;
use utf8;

use autodie;
use Math::BigInt;
use Encode::Locale qw(decode_argv);
use File::Basename qw(basename);
use File::HomeDir qw(home);
use File::Spec::Functions qw(catfile);
use Net::Twitter::Lite::WithAPIv1_1;
use Smart::Options;
use Term::ReadKey qw(ReadMode);
use TOML qw(from_toml to_toml);

use Uc::Model::Twitter;
$Uc::Model::Twitter::Crawler::VERSION = Uc::Model::Twitter->VERSION;

sub configure_encoding {
    STDIN->binmode(":encoding(console_in)");
    STDOUT->binmode(":encoding(console_out)");
    STDERR->binmode(":encoding(console_out)");
    decode_argv();
}

sub get_option_parser {
    my $parser = Smart::Options->new;

    my $script_file = basename($0);
    my $default_file = get_default_file();
    my @default_options = (
        c => { alias => 'config', type => 'Str', default => $default_file, describe => 'setting file path' },
        p => { alias => 'page',   type => 'Int', default => 1,             describe => 'number of crawling' },
        i => { alias => 'count',  type => 'Int', default => 200,           describe => 'api option: count' },
        m => { alias => 'max_id', type => 'Int',                           describe => 'api option: max_id' },
        a => { alias => 'all',    type => 'Bool',                          describe => 'fetch all pages' },
        'no-store' => { alias => 'no_store', type => 'Bool',               describe => 'not store crawled tweets' },
    );

    # manual
    chomp(my $manual = <<"_USAGE_");
Usage: $script_file <command> -h
_USAGE_
    $parser->usage($manual)->options(
        v => { alias => 'version', type => 'Bool', describe => 'show version' },
    );

    # command: conf
    chomp(my $usage_conf = <<"_USAGE_CONF_");
Usage: $script_file conf [-c config.toml]

this command configures Twitter consumer key, secret key and authentication information.
these settings will be saved in '$default_file' or the file which is geven with -c option
_USAGE_CONF_
    $parser->subcmd( conf => Smart::Options->new->usage($usage_conf)->options(
        c => { alias => 'config', type => 'Str', default => $default_file, describe => 'setting file path' },
    ) );

    # command: user
    chomp(my $usage_user = <<"_USAGE_USER_");
Usage: $script_file user [<screen_name>] [-c config.toml]

crawls <screen_name>'s recent tweets.
command uses the authenticating user if <screen_name> is not given.
_USAGE_USER_
    $parser->subcmd( user => Smart::Options->new->usage($usage_user)->options(@default_options) );

    # command: fav
    chomp(my $usage_fav = <<"_USAGE_FAV_");
Usage: $script_file fav [<screen_name>] [-c config.toml]

crawls <screen_name>'s recent favorites.
command uses the authenticating user if <screen_name> is not given.
_USAGE_FAV_
    $parser->subcmd( fav => Smart::Options->new->usage($usage_fav)->options(@default_options) );

    # command: mention
    chomp(my $usage_mention = <<"_USAGE_MENTION_");
Usage: $script_file mention [-c config.toml]

crawls recent mentions for the authenticating user.
_USAGE_MENTION_
    $parser->subcmd( mention => Smart::Options->new->usage($usage_mention)->options(@default_options) );

    # command: status
    chomp(my $usage_status = <<"_USAGE_STATUS_");
Usage: $script_file status [<status_id> [<status_id>]] [-c config.toml]

crawls <status_id> status.
command read STDIN if '-' is given as <status_id>
_USAGE_STATUS_
    $parser->subcmd( status => Smart::Options->new->usage($usage_status)->options(
        c => { alias => 'config', type => 'Str', default => $default_file, describe => 'setting file path' },
        'no-store' => { alias => 'no_store', type => 'Bool',               describe => 'not store crawled tweets' },
    ) );
    $parser;
}

sub get_default_file {
    catfile(home(), sprintf '.%s', basename($0) =~ s/(?:\.\w+)*$//r);
}

sub slurp {
    local($/) = wantarray ? $/ : undef;
    open my($fh), '<:encoding(utf8)', shift;
    my @line = <$fh>;
    close $fh;

    return $line[0] unless wantarray;
    return @line;
}

sub load_toml {
    my $file = shift;
    my $toml = slurp($file);
    my $data = from_toml($toml);
    $data;
}

sub save_toml {
    my $file = shift;
    my $data = shift;
    map { delete $data->{$_} if not defined $data->{$_} or $data->{$_} eq '' } keys %$data;
    my $toml = to_toml($data);
    open my($fh), '>:encoding(utf8)', $file;
    print $fh $toml;
    close $fh;
    1;
}

sub input_data {
    print shift; chomp(my $input = <STDIN>);
    return $input;
}
sub input_secret {
    ReadMode('noecho');
    my $input = input_data(shift);
    ReadMode('restore'); print "\n";
    return $input;
}

sub new_agent {
    Net::Twitter::Lite::WithAPIv1_1->new(
        ssl            => 1,
        consumer_key   => 1,
        useragent_args => { timeout => 10 },
        @_,
    );
}

sub setup_dbh {
    my $driver_name = lc shift;
    if ($driver_name eq 'sqlite') { return setup_dbh_sqlite(@_);  }
    if ($driver_name eq 'mysql' ) { return setup_dbh_mysql(@_);   }
    else                          { die "'$_' is not supported.\n"; }
}

sub setup_dbh_sqlite {
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,'','',{RaiseError => 1, PrintError => 0, AutoCommit => 1, sqlite_unicode => 1});
}

sub setup_dbh_mysql {
    my $db = shift || 'test';
    my $user = shift;
    my $pass = shift;
    my $dbh = DBI->connect('dbi:mysql:'.$db,$user,$pass,{RaiseError => 1, PrintError => 0, AutoCommit => 1,  mysql_enable_utf8 => 1});
    $dbh->do('SET NAMES utf8mb4');
    $dbh;
}

sub call_api {
    my ($option, $arg) = @_;
    while (($option->{all} or $option->{page}--) && _api($option, $arg)) {
        say sprintf "rest of page: %s (max_id: %s)", ($option->{all} ? 'all' : $option->{page}), $arg->{option}{max_id};
    }
}

sub _api {
    my ($option, $arg) = @_;

    my $nt      = $arg->{agent};
    my $schema  = $arg->{schema};
    my $method  = $arg->{method};
    my $api_arg = $arg->{option};
    my $count   = 0;

    my $tweets = eval { $nt->$method($api_arg); };
    unless ($@) {
        my $txn = $schema->txn_scope;
        for my $t (@$tweets) {
            $schema->find_or_create_status($t) unless $option->{no_store};

            $api_arg->{max_id} = sprintf "%s", Math::BigInt->new($t->{id})-1;
            say sprintf "%.19s: %s: %s", $t->{created_at}, $t->{user}{screen_name}, $t->{text};
        }
        $txn->commit;
        $count = scalar @$tweets;
    }
    else {
        my $name = $api_arg->{screen_name} // "user_id=$api_arg->{user_id}";
        say "$name: $@";
        if (ref $@ and $@->isa('Net::Twitter::Lite::Error')) {
            my $limit = grep {
                say sprintf "code=$_->{code}: $_->{message}";
                $_->{code} == 88;
            } @{$@->twitter_error->{errors}};

            if ($limit) {
                say sprintf "rate limit resets after %d seconds",
                    $@->http_response->headers->{'x-rate-limit-reset'}-time;
            }
        }
    }

    $count;
}

use namespace::clean;
# they're class/instance methods

sub new {
    my $class = shift;
    my %init_arg = @_;
    configure_encoding() if $init_arg{configure_encoding} && -t;

    bless { init_arg => \%init_arg }, $class;
}

sub run {
    my $self = shift;
    my @args = @_;

    my $parser = get_option_parser();
    my $option = $parser->parse(@args);

    pop $option->{cmd_option}{_}
        if exists $option->{cmd_option}
        && scalar @{$option->{cmd_option}{_}} == 1
        && $option->{cmd_option}{_}[0] eq $option->{command};

    my $command = $option->{command} // '';
    if    ($command eq 'conf')    { $self->conf($option->{cmd_option}); }
    elsif ($command eq 'user')    { $self->user($option->{cmd_option}); }
    elsif ($command eq 'fav')     { $self->fav($option->{cmd_option}); }
    elsif ($command eq 'mention') { $self->mention($option->{cmd_option}); }
    elsif ($command eq 'status')  { $self->status($option->{cmd_option}); }
    elsif ($option->{version})    { say $self->VERSION; }
    else                          { $parser->showHelp; }

    $option;
}

sub conf {
    my ($self, $option) = @_;
    my $filename = $option->{config};
    my $config = {};
    my $url = '';
    my $pin = '';
    my $retry = 3;
    my $nt = new_agent();
    my $script_file = basename($0);

    if (-e $filename) {
        $config = load_toml($filename);
        if (exists $config->{consumer_key}) {
            my $anser = input_data("do you want to update consumer key? [y/N]: ");
            if ($anser eq '' || $anser =~ /^[nN]/) {
                $nt->{consumer_key}    = $config->{consumer_key};
                $nt->{consumer_secret} = $config->{consumer_secret};
                goto CONFIGURE_DATABASE;
            }
        }
    }
    else {
        say "'$filename' is not found. new file will be saved.";
    }

    CONSUMER_KEY:    $config->{consumer_key} = input_secret("input Twitter consumer key: ");
                     goto CONSUMER_KEY if $config->{consumer_key} eq '';
    CONSUMER_SECRET: $config->{consumer_secret} = input_secret("input Twitter consumer secret: ");
                     goto CONSUMER_SECRET if $config->{consumer_secret} eq '';

    $nt->{consumer_key}    = $config->{consumer_key};
    $nt->{consumer_secret} = $config->{consumer_secret};

    print "verifying input keys ... ";
    $url = eval { $nt->get_authorization_url; };
    die "invalid key set is given. retry configure.\n" if $@;
    say "ok.";

    INPUT_PIN: print "\n"; $retry--;
    $url = eval { $nt->get_authorization_url; } unless $url;
    say 'please open the following url and allow this app, then enter PIN code.';
    say $url; undef $url;
    $pin = input_data('PIN: ');

    @{$config}{qw/token token_secret user_id screen_name/} = eval { $nt->request_access_token(verifier => $pin); };
    if ($@) {
        if ($retry) {
            say "invalid pin code is given. retry.";
            goto INPUT_PIN;
        }
        else {
            die "invalid pin code is given. retry configure.\n";
        }
    }
    say "authentication is succeeded.";
    $retry = 3;

    CONFIGURE_DATABASE:
    if (exists $config->{driver_name}) {
        my $anser = input_data("do you want to update database settings? [y/N]: ");
        if ($anser eq '' || $anser =~ /^[nN]/) {
            goto CREATE_TABLE;
        }
    }
    INPUT_DB_DRIVER: print "\n"; $retry--;
                     $config->{driver_name} = input_data("select database driver [SQLite/MySQL]: ");
                     if    ($config->{driver_name} =~ /^[sS]/) { $config->{driver_name} = 'SQLite'; }
                     elsif ($config->{driver_name} =~ /^[mM]/) { $config->{driver_name} = 'mysql'; }
                     else { goto INPUT_DB_DRIVER; }

    INPUT_DB_NAME: $config->{db_name} = input_data("input database name: ");
                   goto INPUT_DB_NAME if $config->{db_name} eq '';

    if ($config->{driver_name} eq 'mysql') {
        INPUT_DB_USER: $config->{db_user} = input_data("input database user: ");
        INPUT_DB_PASS: $config->{db_pass} = input_secret("input database pasword: ");
    }

    print "verifying database settings ... ";
    eval { setup_dbh(@{$config}{qw(driver_name db_name db_user db_pass)}); };
    if ($@) {
        if ($retry) {
            say "invalid db settings. retry.";
            goto INPUT_DB_DRIVER;
        }
        else {
            die "invalid db settings. retry configure.\n";
        }
    }
    say "ok.";

    CREATE_TABLE:
    {
        my $anser = input_data("do you want to create table in database '$config->{db_name}'? [Y/n]: ");
        if ($anser =~ /^[nN]/) {
            goto FINISH_CONFIGURE;
        }
        else {
            my $anser = input_data("do you want to do 'force create'? [y/N]: ");
            my $if_not_exists = $anser =~ /[nN]/ ? 1 : 0;
            my $schema = Uc::Model::Twitter->new( dbh => setup_dbh(@{$config}{qw(driver_name db_name db_user db_pass)}) );
            $schema->create_table(if_not_exists => $if_not_exists);
        }
    }

    FINISH_CONFIGURE:
    say "$script_file is configured. command '$script_file -h' to check how to use.";
    say "sample command: '$script_file user $config->{screen_name} -c $filename'";

    save_toml($filename, $config);
}

sub user {
    my ($self, $option) = @_;
    $self->crawl('user_timeline', $option);
}

sub fav {
    my ($self, $option) = @_;
    $self->crawl('favorites', $option);
}

sub mention {
    my ($self, $option) = @_;
    $option->{_} = [];
    $self->crawl('mentions', $option);
}

sub crawl {
    my ($self, $method, $option) = @_;
    my $filename = $option->{config};
    die "'$filename' is not found. you should '$0 conf' before this command."
        unless -e $filename;

    my $config = load_toml($filename);
    my $nt = new_agent(
        consumer_key        => $config->{consumer_key},
        consumer_secret     => $config->{consumer_secret},
        access_token        => $config->{token},
        access_token_secret => $config->{token_secret},
    );
    my $schema = Uc::Model::Twitter->new( dbh => setup_dbh(@{$config}{qw(driver_name db_name db_user db_pass)}) );

    my $api_arg = {
        agent => $nt,
        schema => $schema,
        method => $method,
        option => { count => $option->{count} },
    };
    $api_arg->{option}{since_id} = $option->{since_id} if exists $option->{since_id};
    $api_arg->{option}{max_id}   = $option->{max_id}   if exists $option->{max_id};

    if (scalar @{$option->{_}}) {
        for my $screen_name (@{$option->{_}}) {
            $api_arg->{option}{screen_name} = $screen_name;
            call_api($option, $api_arg);
        }
    }
    else {
        $api_arg->{option}{user_id} = $config->{user_id};
        call_api($option, $api_arg);
    }
}

sub status {
    my ($self, $option) = @_;
    my $filename = $option->{config};
    die "'$filename' is not found. you should '$0 conf' before this command."
        unless -e $filename;

    my $config = load_toml($filename);
    my $nt = new_agent(
        consumer_key        => $config->{consumer_key},
        consumer_secret     => $config->{consumer_secret},
        access_token        => $config->{token},
        access_token_secret => $config->{token_secret},
    );
    my $schema = Uc::Model::Twitter->new( dbh => setup_dbh(@{$config}{qw(driver_name db_name db_user db_pass)}) );

    if (scalar @{$option->{_}} == 1 and $option->{_}[0] eq '-') {
        chomp(@{$option->{_}} = <STDIN>);
    }

    while (my $status_id = shift $option->{_}) {
        my $t = eval { $nt->show_status({ id => $status_id }); };
        unless ($@) {
            $schema->find_or_create_status($t) unless $option->{no_store};
            say sprintf "%s: %.19s: %s: %s", $t->{id}, $t->{created_at}, $t->{user}{screen_name}, $t->{text};
        }
        else {
            say "status_id=$status_id: $@";
            if (ref $@ and $@->isa('Net::Twitter::Lite::Error') and $@->code != 404) {
                unshift $option->{_}, $status_id;

                my $limit = grep {
                    say sprintf "code=$_->{code}: $_->{message}";
                    $_->{code} == 88;
                } @{$@->twitter_error->{errors}};

                if ($limit) {
                    my $reset = $@->http_response->headers->{'x-rate-limit-reset'};
                    while ((my $sleep = $reset-time) > 0) {
                        print sprintf "sleep %d seconds\r", $sleep; sleep 1;
                    }
                }
                else {
                    my $wakeup = time+5;
                    while ((my $sleep = $wakeup-time) > 0) {
                        print sprintf "sleep %d seconds\r", $sleep; sleep 1;
                    }
                }
            }
        }
    }
}

1; # Magic true value required at end of module
__END__

=encoding utf-8

=head1 NAME

Uc::Model::Twitter::Crawler - ucrawl-tweet's class

=head1 SYNOPSIS

    $ ucrawl-tweet user c18t

=head1 DESCRIPTION

Uc::Model::Twitter::Crawler is the generater class of ucrawl-tweet command's instance.

=head1 DEPENDENCIES

=over 2

=item L<perl> >= 5.14

=item L<Encode::Locale> >= 1.03

=item L<File::HomeDir> >= 1.00

=item L<Net::OAuth> >= 0.26

=item L<Net::Twitter::Lite> >= 0.12006

=item L<Smart::Options> >= 0.053

=item L<Term::ReadKey> >= 2.31

=item L<TOML> => 0.92

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
L<https://github.com/UCormorant/p5-uc-model-twitter/issues>

=head1 AUTHOR

U=Cormorant E<lt>u@chimata.orgE<gt>

=head1 LICENSE

Copyright (C) U=Cormorant.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 SEE ALSO

L<https://github.com/UCormorant/p5-uc-model-twitter>

=cut
