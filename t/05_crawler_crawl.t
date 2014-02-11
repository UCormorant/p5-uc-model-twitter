use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Test::Mock::Guard qw(mock_guard);
use Capture::Tiny qw(capture capture_merged);
use DBI;
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catfile);
use Scope::Guard qw(scope_guard);
use TOML qw(from_toml to_toml);

use Uc::Model::Twitter::Crawler;

sub local_term (&@) { _local_term(capture => @_); }
sub local_term_merged (&@) { _local_term(capture_merged => @_); }
sub _local_term {
    my $sub_name = shift;
    my $block = shift;
    local *STDIN;
    local *STDOUT;
    local *STDERR;
    local(@ARGV) = @_;

    no strict 'refs';
    &{"$sub_name"}(sub {
        Uc::Model::Twitter::Crawler->new( configure_encoding => 1 );
        $block->(@ARGV);
    });
}

plan tests => 1;

subtest 'ucrawl-tweet' => sub {
    my $class;
    my $config;
    my $config_file;
    my $script_file = basename($0);
    my $home_guard = t::Util->fake_home;
    my $verify_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
        verify_credentials => 1,
    };

    $config = from_toml(t::Util->slurp(catfile(dirname(__FILE__), 'crawler_config.toml'), 'abs'));
    $config->{db_name} = catfile($ENV{HOME}, 'db.sqlite');
    $config_file = catfile($ENV{HOME}, 'config.toml');
    t::Util->store($config_file, to_toml($config), 'abs');

    before { $class = Uc::Model::Twitter::Crawler->new(); };
    after  { undef $class; };

    plan tests => 2;

    subtest('$class->can' => sub {
        plan tests => 6;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        can_ok $class, $_ for qw(
            user
            fav
            mention

            run
            crawl
        );
    }) or return; # stop test unless all method can be called

    my $crawl_test = sub {
        my ($command, $ua_method, %ignore_test) = @_; return sub {
        plan tests => 4;

        my (@args, $output, $stdout, $stderr);
        my $nt_class = 'Net::Twitter::Lite::WithAPIv1_1';

        subtest 'show help' => sub {
            if ($ignore_test{show_help})
                { plan skip_all => $ignore_test{show_help}; }
            else
                { plan tests => 7; }

            @args = ($command, qw(-h));
            $output = local_term_merged { eval { $class->run(@_); }; } @args;
            like $output, qr/^Usage: $script_file $args[0]/, 'show help';
            like $output, qr/--config/,   'help text says about -c option';
            like $output, qr/--page/,     'help text says about -p option';
            like $output, qr/--count/,    'help text says about -i option';
            like $output, qr/--max_id/,   'help text says about -m option';
            like $output, qr/--all/,      'help text says about -a option';
            like $output, qr/--no-store/, 'help text says about --no-store option';
        };

        subtest 'fail test' => sub {
            if ($ignore_test{fail_test})
                { plan skip_all => $ignore_test{fail_test}; }
            else
                { plan tests => 11; }

            my $mock_guard;

            # 404
            $mock_guard = mock_guard $nt_class => +{
                $ua_method => sub {
                    die Net::Twitter::Lite::Error->new(
                        http_response => HTTP::Response->new(404 => 'Not Found'),
                        twitter_error => t::Util->open_json_file('twitter_error.34.json'),
                    );
                },
            };
            @args = ($command, qw(-c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            like $stdout, qr/\buser_id=\d+/, 'show authenticating user id';
            like $stdout, qr/\b404\b/, 'show http status code';
            like $stdout, qr/\bcode=34\b/, 'show twitter error code';
            is $stderr, '', 'no warning is occered';

            undef $mock_guard;

            # 429
            $mock_guard = mock_guard $nt_class => +{
                $ua_method => sub {
                    die Net::Twitter::Lite::Error->new(
                        http_response => HTTP::Response->new(429 => 'Too Many Requests'),
                        twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                    );
                },
            };
            @args = ($command, qw(-c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            like $stdout, qr/\buser_id=\d+/, 'show authenticating user id';
            like $stdout, qr/\b429\b/, 'show http status code';
            like $stdout, qr/\bcode=88\b/, 'show twitter error code';
            is $stderr, '', 'no warning is occered';

            # without twitter_error
            $mock_guard = mock_guard $nt_class => +{
                $ua_method => sub {
                    die Net::Twitter::Lite::Error->new(
                        http_response => HTTP::Response->new(
                            500 => 'Internal Server Error',
                        ),
                    );
                },
            };
            @args = ($command, qw(-c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            like $stdout, qr/\buser_id=\d+/, 'show authenticating user id';
            like $stdout, qr/\b500\b/, 'show http status code';
            is $stderr, '', 'no warning is occered';
        };

        subtest 'options' => sub {
            if ($ignore_test{options})
                { plan skip_all => $ignore_test{options}; }
            else
                { plan tests => 10; }

            my $mock_guard;

            my $count = 0;
            $mock_guard = mock_guard $nt_class => +{
                $ua_method => sub {
                    my $tweets = [];
                    if (++$count <= 5) {
                        $tweets = t::Util->open_json_file("user_timeline.json");
                    }
                    return $tweets;
                },
            };

            # no option
            @args = ($command, qw(-c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $mock_guard->call_count($nt_class,$ua_method), 1, 'call api once';
            like $stdout, qr/rest of page: 0 \(max_id: \d+\)/, 'show number of rest of page and max_id';
            is $stderr, '', 'no warning is occered';

            # page option
            @args = ($command, qw(-p 2 -c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $mock_guard->call_count($nt_class,$ua_method), 3, 'call api 3 times total';
            like $stdout, qr/rest of page: 1 \(max_id: \d+\)/, 'show number 1 and max_id';
            like $stdout, qr/rest of page: 0 \(max_id: \d+\)/, 'show number 0 and max_id';
            is $stderr, '', 'no warning is occered';

            # all option
            @args = ($command, qw(-a -c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $mock_guard->call_count($nt_class,$ua_method), 6, 'call api 6 times total';
            like $stdout, qr/rest of page: all \(max_id: \d+\)/, 'show max_id';
            is $stderr, '', 'no warning is occered';
        };

        subtest 'many users' => sub {
            if ($ignore_test{many_users})
                { plan skip_all => $ignore_test{many_users}; }
            else
                { plan tests => 3; }

            my $mock_guard;

            my $count = 0;
            $mock_guard = mock_guard $nt_class => +{
                $ua_method => sub {
                    my $tweets = [];
                    if (++$count == 3) {
                        die Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(404 => 'Not Found'),
                            twitter_error => t::Util->open_json_file('twitter_error.34.json'),
                        );
                    }
                    else {
                        $tweets = t::Util->open_json_file("user_timeline.json");
                    }

                    return $tweets;
                },
            };

            @args = ($command, qw(a b c -p 2 -c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $mock_guard->call_count($nt_class,$ua_method), 5, 'call api 5 times total';
            like $stdout, qr/\bb: 404\b/, 'show failed user\'s screen_name b and http status 404';
            is $stderr, '', 'no warning is occered';
        };
    }; };

    subtest 'run' => sub {
        my $schema = Uc::Model::Twitter->new(
            dbh => t::Util->setup_sqlite_dbh(@{$config}{qw(db_name db_user db_pass)}),
        );
        before { $schema->create_table; };
        after  { $schema->drop_table;   };

        plan tests => 4;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        subtest 'command user'    => $crawl_test->('user',    'user_timeline');
        subtest 'command fav'     => $crawl_test->('fav',     'favorites');
        subtest 'command mention' => $crawl_test->('mention', 'mentions', many_users => 'needless test');

    };
};

done_testing;
