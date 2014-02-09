use 5.010;
use Net::Twitter::Lite::WithAPIv1_1;

sub twitter_agent {
    my ($conf_app, $conf_user) = @_;
    my $nt = Net::Twitter::Lite::WithAPIv1_1->new(%$conf_app, useragent_args => +{ timeout => 10 }, ssl => 1);
    $nt->access_token($conf_user->{token});
    $nt->access_token_secret($conf_user->{token_secret});

    my ($pin, @userdata);
    while (not ($nt->{authorized} = !!eval { $nt->verify_credentials; })) {
        my $url = eval { $nt->get_authorization_url(); };
        say 'please open the following url and allow this app, then enter PIN code.';
        say $url;
        print 'PIN: '; chomp($pin = <STDIN>);

        @{$conf_user}{qw/token token_secret user_id screen_name/} = $nt->request_access_token(verifier => $pin);
        $nt->{config_updated} = 1;
    }

    return $nt;
}

1;
