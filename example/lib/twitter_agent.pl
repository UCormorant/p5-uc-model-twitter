use 5.010;
use Net::Twitter::Lite;

sub twitter_agent {
    my ($conf_app, $conf_user) = @_;
    my $nt = Net::Twitter::Lite->new(ssl => 1, legacy_lists_api => 0, %$conf_app);
    $nt->access_token($conf_user->{token});
    $nt->access_token_secret($conf_user->{token_secret});

    my ($pin, @userdata);
    while (!$nt->authorized()) {
        say 'please open the following url and allow this app, then enter PIN code.';
        say $nt->get_authorization_url();
        print 'PIN: '; chomp($pin = <STDIN>);

        @{$conf_user}{qw/token token_secret user_id screen_name/} = $nt->request_access_token(verifier => $pin);
        $nt->{config_updated} = 1;
    }

    return $nt;
}

1;
