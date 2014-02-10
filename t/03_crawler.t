use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Test::Mock::Guard qw(mock_guard);
use Scope::Guard qw(scope_guard);
use Capture::Tiny qw(capture capture_merged);
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catfile);
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
    my $tempdir = t::Util->tempfolder;
    my $script_file = basename($0);
    my $config_file = catfile(dirname(__FILE__), 'crawler_config.toml');
    my $config = from_toml(t::Util->slurp('crawler_config.toml'));
    my $verify_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
        verify_credentials => 1,
    };
    $config_file = catfile($tempdir, 'config.toml');
    $config->{db_name} = catfile($tempdir, 'db.sqlite');
    t::Util->store($config_file, to_toml($config), 1);

    before { $class = Uc::Model::Twitter::Crawler->new(); };
    after  { undef $class; };

    plan tests => 2;

    subtest('$class->can' => sub {
        plan tests => 8;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        can_ok $class, $_ for qw(
            conf
            user
            fav
            mention
            status

            run
            crawl
        );
    }) or return; # stop test unless all method can be called

    my $crawl_test = sub {
        my ($command, $ua_method, %ignore_test) = @_; return sub {
        plan tests => 4;

        my (@args, $output, $stdout, $stderr);

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
                { plan tests => 8; }

            my $mock_guard;

            # 404
            $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
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
            $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
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
        };

        subtest 'options' => sub {
            if ($ignore_test{options})
                { plan skip_all => $ignore_test{options}; }
            else
                { plan tests => 10; }

            my $mock_guard;

            my $count = 0;
            $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
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
            is $count, 1, 'call api once';
            like $stdout, qr/rest of page: 0 \(max_id: \d+\)/, 'show number of rest of page and max_id';
            is $stderr, '', 'no warning is occered';

            # page option
            @args = ($command, qw(-p 2 -c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $count, 3, 'call api 3 times total';
            like $stdout, qr/rest of page: 1 \(max_id: \d+\)/, 'show number 1 and max_id';
            like $stdout, qr/rest of page: 0 \(max_id: \d+\)/, 'show number 0 and max_id';
            is $stderr, '', 'no warning is occered';

            # all option
            @args = ($command, qw(-a -c), $config_file);
            ($stdout, $stderr) = local_term { $class->run(@_); } @args;
            is $count, 6, 'call api 6 times total';
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
            $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
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
            is $count, 5, 'call api 5 times';
            like $stdout, qr/\bb: 404\b/, 'show failed user\'s screen_name b and http status 404';
            is $stderr, '', 'no warning is occered';
        };
    }; };

    subtest 'run' => sub {
        my $schema = Uc::Model::Twitter->new(
            dbh => t::Util->setup_sqlite_dbh(@{$config}{qw(db_name db_user db_pass)}),
        );
        before { $schema->create_table; };
        after  { $schema->drop_table; };

        plan tests => 7;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        subtest 'no commnad' => sub {
            plan tests => 9;

            my (@args, $output);

            @args = ();
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/^Usage: $script_file/, 'show help';
            like $output, qr/--version/, 'help text says about -v option';

            @args = qw(-h);
            $output = local_term_merged { eval { $class->run(@_); }; } @args;
            like $output, qr/\bconf\b/,    'command conf is defined';
            like $output, qr/\buser\b/,    'command user is defined';
            like $output, qr/\bfav\b/,     'command fav is defined';
            like $output, qr/\bmention\b/, 'command mention is defined';
            like $output, qr/\bstatus\b/,  'command status is defined';

            @args = qw(-v);
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '-v shows version';

            @args = qw(--version);
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '--version shows version';
        };

        subtest 'command conf' => sub {
            plan tests => 2;

            my (@args, $output, @result, $stdout, $stderr, $mock_guard);

            # show help
            @args = qw(conf -h);
            ($output, @result) = local_term_merged { eval { $class->run(@_); }; } @args;
            like $output, qr/^Usage: $script_file $args[0]/, 'show help';
            like $output, qr/--config/,   'help text says about -c option';
        };

        subtest 'command user'    => $crawl_test->('user',    'user_timeline');
        subtest 'command fav'     => $crawl_test->('fav',     'favorites');
        subtest 'command mention' => $crawl_test->('mention', 'mentions', many_users => 'needless test');

        subtest 'command status' => sub {
            plan tests => 3;

            my $command = 'status';
            my $ua_method = 'show_status';
            my (@args, $output, $stdout, $stderr, $mock_guard);

            subtest 'show help' => sub {
                plan tests => 3;

                @args = ($command, qw(-h));
                $output = local_term_merged { eval { $class->run(@_); }; } @args;
                like $output, qr/^Usage: $script_file $args[0]/, 'show help';
                like $output, qr/--config/,   'help text says about -c option';
                like $output, qr/--no-store/, 'help text says about --no-store option';
            };

            subtest 'fail test' => sub {
                plan tests => 19;

                my $mock_guard;
                my $count;

                # 403
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        die Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(403 => 'Forbidden'),
                            twitter_error => t::Util->open_json_file('twitter_error.179.json'),
                        );
                    },
                };
                @args = ($command, qw(1 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like   $stdout, qr/\bstatus_id=1/, 'show status id';
                like   $stdout, qr/\b403\b/, 'show http status code';
                unlike $stdout, qr/\bcode=179\b/, 'does not show twitter error code';
                is $stderr, '', 'no warning is occered';

                # 404
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        die Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(404 => 'Not Found'),
                            twitter_error => t::Util->open_json_file('twitter_error.34.json'),
                        );
                    },
                };
                @args = ($command, qw(1 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like   $stdout, qr/\bstatus_id=1/, 'show status id';
                like   $stdout, qr/\b404\b/, 'show http status code';
                unlike $stdout, qr/\bcode=34\b/, 'does not show twitter error code';
                is $stderr, '', 'no warning is occered';

                undef $mock_guard;

                # 429
                $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        if (!$count++) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    429 => 'Too Many Requests',
                                    ['x-api-limit-reset' => time+3],
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                            );
                        }
                        return t::Util->open_json_file("status.exclude_retweet.json");
                    },
                };
                @args = ($command, qw(2 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like $stdout, qr/\bstatus_id=2/, 'show status id';
                like $stdout, qr/\b429\b/, 'show http status code';
                like $stdout, qr/\bcode=88\b/, 'show twitter error code';
                is $count, 2, 'sleeped once';
                is $stderr, '', 'no warning is occered';

                # 500
                $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        if (!$count++) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    500 => 'Internal Server Error',
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.131.json'),
                            );
                        }
                        return t::Util->open_json_file("status.exclude_retweet.json");
                    },
                };
                @args = ($command, qw(3 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like $stdout, qr/\bstatus_id=3/, 'show status id';
                like $stdout, qr/\b500\b/, 'show http status code';
                like $stdout, qr/\bcode=131\b/, 'show twitter error code';
                like $stdout, qr/\bsleep \d\b/, 'show sleep time';
                is $count, 2, 'sleeped once';
                is $stderr, '', 'no warning is occered';
            };

            subtest 'status_id from ARGV' => sub {
                plan tests => 7;

                my $mock_guard;

                my $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        my $self = shift;
                        my $query = shift;
                        if (++$count == 2) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    429 => 'Too Many Requests',
                                    ['x-api-limit-reset' => time+3],
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                            );
                        }
                        elsif ($count == 5 ) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    403 => 'Forbidden',
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.179.json'),
                            );
                        }

                        my $tweet = t::Util->open_json_file("status.exclude_retweet.json");
                        $tweet->{id} = $query->{id};
                        return $tweet;
                    },
                };

                @args = ($command, qw(1 2 3 4 5 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                is $count, 6, 'call api once';
                like   $stdout, qr/^1:/m, 'get id 1';
                like   $stdout, qr/^2:/m, 'get id 2';
                like   $stdout, qr/^3:/m, 'get id 3';
                unlike $stdout, qr/^4:/m, 'do not get id 4';
                like   $stdout, qr/^5:/m, 'get id 5';
                is $stderr, '', 'no warning is occered';
            };
        };
    };
};

done_testing;
