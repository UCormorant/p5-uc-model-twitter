use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Scope::Guard qw(scope_guard);

use Uc::Model::Twitter;
Uc::Model::Twitter->load_plugin('Count');

plan tests => 1;

my $DB_HANDLE = eval {t::Util->setup_sqlite_dbh()};
if ($@) { fail 'DBD::SQLite setup error'; return; }

subtest "sqlite test" => sub {
    my $class;
    before { $class = Uc::Model::Twitter->new( dbh => $DB_HANDLE ); };
    after  { undef $class; };

    plan tests => 4;

    subtest("\$class->can" => sub {
        plan tests => 6;
        isa_ok $class, 'Uc::Model::Twitter', '$class';

        can_ok $class, $_ for qw(
            create_table
            drop_table
            find_or_create_profile
            find_or_create_status
            update_or_create_remark
        );
    }) or return; # stop test unless all method can be called

    subtest "connect and setup database" => sub {
        plan tests => 4;
        isa_ok $class, 'Uc::Model::Twitter', '$class';

        subtest "create and drop table (with unknown driver)" => sub {
            my $DB_DRIVER = $DB_HANDLE->{Driver}{Name};
            my $guard = scope_guard sub {
                $DB_HANDLE->{Driver}{Name} = $DB_DRIVER;
            };

            plan tests => 2;
            $DB_HANDLE->{Driver}{Name} = 'unknown';
            throws_ok { $class->create_table; } qr/'$DB_HANDLE->{Driver}{Name}'/,
                'create_table() throw an error that includes driver name';
            throws_ok { $class->drop_table; } qr/'$DB_HANDLE->{Driver}{Name}'/,
                'drop_table() throw an error that includes driver name';
        };

        subtest "create and drop table" => sub {
            plan tests => 2;
            my($sth, @got);
            my $table_name = 'uc_model_twitter';
            my %expect = (profile_image => 1, remark => 1, status => 1, user => 1, $table_name => 0);

            $sth = $DB_HANDLE->prepare(q{
                SELECT count(*) FROM sqlite_master
                    WHERE type='table' AND name=?;
            });

            $class->do(qq{DROP TABLE IF EXISTS $table_name});
            $class->create_table;

            $expect{$table_name} = 0; # expect '$table_name' is dropped
            @got = ();
            for my $table (sort keys %expect) {
                $sth->execute($table);
                push @got, $table if $sth->fetchrow_arrayref->[0];
            }
            is_deeply \@got, [sort grep { $expect{$_} } keys %expect], '4 tables are created';

            # create other table
            $class->do(qq{CREATE TABLE $table_name (id int primary key, value text)});
            $class->drop_table;

            $expect{$table_name} = 1; # expect '$table_name' is not dropped
            @got = ();
            for my $table (sort keys %expect) {
                $sth->execute($table);
                push @got, $table if $sth->fetchrow_arrayref->[0];
            }
            ok !!(scalar @got == 1 && $got[0] eq $table_name), '4 tables are dropped';

            $class->do(qq{DROP TABLE IF EXISTS $table_name});
        };

        subtest "create_table with if_not_exists" => sub {
            plan tests => 3;
            my($sth, @got);
            my $drop_table = 'user';
            my %expect = (profile_image => 1, remark => 1, status => 1, user => 0);

            $sth = $DB_HANDLE->prepare(q{
                SELECT count(*) FROM sqlite_master
                    WHERE type='table' AND name=?;
            });

            # force create table
            $class->create_table(if_not_exists => 0);

            # insert rows into 'status'
            my $status = t::Util->open_json_file('t/status.exclude_retweet.json');
            my $tweet = $class->find_or_create_status($status);

            # drop table 'user'
            $class->drop_table($drop_table);

            $expect{user} = 0; # expect 'user' is dropped
            @got = ();
            for my $table (sort keys %expect) {
                $sth->execute($table);
                push @got, $table if $sth->fetchrow_arrayref->[0];
            }
            is_deeply \@got, [sort grep { $expect{$_} } keys %expect], '3 tables are created';

            # create dropped table 'user'
            $class->create_table();

            $expect{user} = 1; # expect 'user' is created
            @got = ();
            for my $table (sort keys %expect) {
                $sth->execute($table);
                push @got, $table if $sth->fetchrow_arrayref->[0];
            }
            is_deeply \@got, [sort grep { $expect{$_} } keys %expect], '4 tables are created';

            # don't drops other tables
            @got = $class->single('status', { id => $tweet->id });
            ok scalar @got, "'status' table is not dropped even though drop table 'user'";

            $class->drop_table();
        };
    };

    subtest "database manipulation methods" => sub {
        before { $class->create_table; };
        after  { $class->drop_table; };

        plan tests => 7;

        subtest "find_or_create_profile" => sub {
            plan tests => 6;

            # get tweet
            my $status = t::Util->open_json_file('t/status.exclude_retweet.json');

            # create
            my $user1 = $class->find_or_create_profile($status->{user});
            isa_ok $user1, 'Uc::Model::Twitter::Row::User', 'retval of create a profile';

            # find
            my $user2 = $class->find_or_create_profile($status->{user});
            isa_ok $user2, 'Uc::Model::Twitter::Row::User', 'retval of find a profile';
            ok $class->count('user') == 1, 'same profile is never created';

            # create other profile
            $status->{user}{name} = 'Cormorant';
            my $user3 = $class->find_or_create_profile($status->{user});
            isa_ok $user3, 'Uc::Model::Twitter::Row::User', 'retval of create other profile';

            ok(!!($user1->id == $user2->id and $user1->profile_id eq $user2->profile_id), 'call the method with same profiles')
                or diag explain [
                    { n => 1, id => $user1->id, profile_id => $user1->profile_id },
                    { n => 2, id => $user2->id, profile_id => $user2->profile_id },
                ];
            ok(!!($user1->id == $user3->id and $user1->profile_id ne $user3->profile_id), 'call the method with different profiles')
                or diag explain [
                    { n => 1, id => $user1->id, profile_id => $user1->profile_id },
                    { n => 3, id => $user3->id, profile_id => $user3->profile_id },
                ];
        };

        subtest "find_or_create_status (without user object)" => sub {
            plan tests => 1;

            # get tweet
            my $status = t::Util->open_json_file('t/status.exclude_retweet.json');
            delete $status->{user};

            dies_ok { $class->find_or_create_status($status); } 'expecting to die if user object is not defined';
        };

        subtest "find_or_create_status" => sub {
            plan tests => 6;

            # get tweet
            my $status = t::Util->open_json_file('t/status.exclude_retweet.json');

            # create
            my $tweet1 = $class->find_or_create_status($status);
            isa_ok $tweet1, 'Uc::Model::Twitter::Row::Status', 'retval of create a status';

            # find
            my $tweet2 = $class->find_or_create_status($status);
            isa_ok $tweet2, 'Uc::Model::Twitter::Row::Status', 'retval of find a status';
            ok $class->count('status') == 1, 'same tweet is never stored';

            # single
            my $tweet3 = $class->single('status', { id => $status->{id} });
            isa_ok $tweet3, 'Uc::Model::Twitter::Row::Status', 'retval of find a status by id';

            # cmp 3 results
            ok(!!($tweet1->id eq $tweet2->id and $tweet1->id eq $tweet3->id), 'searching with a same id retuerns same row')
                or diag explain [
                    { n => 1, id => $tweet1->id },
                    { n => 2, id => $tweet2->id },
                    { n => 3, id => $tweet3->id },
                ];

            # check inflate
            isa_ok $tweet1->created_at, 'DateTime', 'tweet->created_at';
        };

        subtest "find_or_create_status (with retweet)" => sub {
            plan tests => 8;

            # get tweet with retweet
            my $status = t::Util->open_json_file('t/status.include_retweet.json');

            # create
            my $tweet1 = $class->find_or_create_status($status);
            isa_ok $tweet1, 'Uc::Model::Twitter::Row::Status', 'retval of create a status with retweet';
            ok $class->count('status') == 2, 'create a retweet and its original tweet';

            # find
            my $tweet2 = $class->find_or_create_status($status);
            isa_ok $tweet2, 'Uc::Model::Twitter::Row::Status', 'retval of find a retweet';
            ok $class->count('status') == 2, 'same tweet is never stored';

            # single
            my $tweet3 = $class->single('status', { id => $status->{id} });
            isa_ok $tweet2, 'Uc::Model::Twitter::Row::Status', 'retval of find a retweet by id';

            # cmp 3 results
            ok(!!($tweet1->id eq $tweet2->id and $tweet1->id eq $tweet3->id), 'searching with a same id retuerns same row')
                or diag explain [
                    { n => 1, id => $tweet1->id },
                    { n => 2, id => $tweet2->id },
                    { n => 3, id => $tweet3->id },
                ];

            # get original tweet
            my $tweet_orig = $class->single('status', { id => $tweet1->retweeted_status_id });
            isa_ok $tweet_orig, 'Uc::Model::Twitter::Row::Status', 'retval of find a original tweet by id';

            # check relation
            ok $tweet1->retweeted_status_id eq $tweet_orig->id, 'check relation';
        };

        subtest "update_or_create_remark" => sub {
            plan tests => 7;

            # get tweet with retweet
            my $status = t::Util->open_json_file('t/status.include_retweet.json');

            my $tweet = $class->find_or_create_status($status);
            isa_ok $tweet, 'Uc::Model::Twitter::Row::Status', 'retval of create a status with retweet';

            # target is original tweet
            my %update = (
                id => $tweet->retweeted_status_id,
                user_id => $tweet->user_id,
                status_user_id => $tweet->user_id,
            );

            # mark as retweeted status
            $update{retweeted} = 1;

            my $remark1 = $class->update_or_create_remark(\%update);
            isa_ok $remark1, 'Uc::Model::Twitter::Row::Remark', 'retval of mark as retweeted status';

            ok $remark1->retweeted, 'target tweet is marked as retweeted status';
            ok(!!($remark1->id == $tweet->retweeted_status_id and $remark1->user_id == $tweet->user_id),
                'check relation') or diag explain [
                    { remark_id => $remark1->id, retweeted_status_id => $tweet->retweeted_status_id },
                    { remark_user_id => $remark1->user_id, tweet_user_id => $tweet->user_id },
                ];

            # unmark as retweeted and mark as favorited
            $update{retweeted} = 0;
            $update{favorited} = 1;

            my $remark2 = $class->update_or_create_remark(\%update);
            isa_ok $remark2, 'Uc::Model::Twitter::Row::Remark', 'retval of update remarks';

            ok ! $remark2->retweeted, 'target is unretweeted';
            ok   $remark2->favorited, 'target is favorited';
        };

        subtest "update_or_create_remark (with retweet)" => sub {
            plan tests => 11;

            # get tweet with retweet
            my $status = t::Util->open_json_file('t/status.include_retweet.json');

            my $tweet = $class->find_or_create_status($status);
            isa_ok $tweet, 'Uc::Model::Twitter::Row::Status', 'retval of create a status with retweet';

            # retweet 'RT status'
            my %update = (
                id => $tweet->id,
                user_id => $tweet->user_id,
                status_user_id => $tweet->user_id,
            );
            $update{retweeted} = 1;

            my $remark1 = $class->update_or_create_remark(
                \%update,
                {
                    retweeted_status_id => $status->{retweeted_status}{id},
                    retweeted_status_user_id => $status->{retweeted_status}{user}{id},
                }
            );
            isa_ok $remark1, 'Uc::Model::Twitter::Row::Remark', 'retval retweet \'RT status\'';

            # find original tweet's mark
            my $remark2 = $class->single('remark', { id => $tweet->retweeted_status_id });
            isa_ok $remark2, 'Uc::Model::Twitter::Row::Remark', 'retval of find RT status\'s mark';

            ok $remark1->retweeted, 'target is retweeted';
            ok $remark2->retweeted, 'original tweet is also marked as retweeted';

            # unmark as retweeted and mark as favorited
            $update{retweeted} = 0;
            $update{favorited} = 1;

            my $remark3 = $class->update_or_create_remark(\%update);
            isa_ok $remark3, 'Uc::Model::Twitter::Row::Remark', 'retval of update RT status\'s mark';

            my $remark4 = $class->single('remark', { id => $tweet->retweeted_status_id });
            isa_ok $remark4, 'Uc::Model::Twitter::Row::Remark', 'retval of get original tweet\'s mark';

            ok ! $remark3->retweeted, 'target is unretweeted';
            ok   $remark3->favorited, 'target is favorited';
            cmp_ok $remark3->retweeted, '==', $remark4->retweeted, 'original is unretweeted too';
            cmp_ok $remark3->favorited, '==', $remark4->favorited, 'original is favorited too';
        };

        subtest 'find_or_create_status (with options)' => sub {
            plan tests => 9;

            # get tweet
            my $status = t::Util->open_json_file('t/status.remark.json');
            my $attr = { user_id => $status->{user}{id}, ignore_unmarking => 0 };

            # favorite, retweet
            $status->{favorited} = 1;
            $status->{retweeted} = 1;
            my $tweet1 = $class->find_or_create_status($status, $attr);
            my @remarks1 = $class->search('remark', { id => $tweet1->id, user_id => $attr->{user_id} });

            is scalar @remarks1, 1, '1 remark';
            ok   $remarks1[0]->favorited, 'target is favorited';
            ok   $remarks1[0]->retweeted, 'target is retweeted';

            # unfavorite
            $status->{favorited} = 0;
            $status->{retweeted} = 1;
            my $tweet2 = $class->find_or_create_status($status, $attr);
            my @remarks2 = $class->search('remark', { id => $tweet2->id, user_id => $attr->{user_id} });

            is scalar @remarks2, 1, '1 remark';
            ok ! $remarks2[0]->favorited, 'target is unfavorited';
            ok   $remarks2[0]->retweeted, 'target is retweeted';

            # ignore_unmarking
            $status->{favorited} = 1;
            $status->{retweeted} = 0;
            $attr->{ignore_unmarking} = 1;
            my $tweet3 = $class->find_or_create_status($status, $attr);
            my @remarks3 = $class->search('remark', { id => $tweet3->id, user_id => $attr->{user_id} });

            is scalar @remarks3, 1, '1 remark';
            ok   $remarks3[0]->favorited, 'target is favorited';
            ok   $remarks3[0]->retweeted, 'target is not unretweeted (ignore_unmarking)';
        };
    };

    subtest 'table relationship' => sub {
        my $statuses = t::Util->open_json_file('t/status.table_relationship.json');
        my $attr = { user_id => $statuses->[0]{user}{id} };
        my $guard = scope_guard sub { $class->drop_table };

        $class->create_table;
        $class->find_or_create_status($_, $attr) for @$statuses;

        plan tests => 3;

        subtest 'Row::Status' => sub {
            plan tests => 10;

            # Row::Status
            my $tweet1 = $class->single('status', { id => "240859602684612608" });

            # -> Row::User
            my $user1  = $tweet1->user; # belongs_to
            is $user1->screen_name, "twitterapi1", 'expected profile';

            # -> Row::Remark
            is scalar @{[$tweet1->favorited]}, 1, '$tweet1 has 1 favorited'; # has_many
            is scalar @{[$tweet1->retweeted]}, 0, '$tweet1 has no retweeted'; # has_many
            my @remarks1 = $tweet1->remarked; # has_many
            is scalar @remarks1, 1, '$tweet1 has 1 remark';
            ok(!!(sprintf("%s", $remarks1[0]->user_id) eq "$attr->{user_id}" && $remarks1[0]->favorited && ! $remarks1[0]->retweeted),
                'expected remark') or diag explain {
                    user_id => $attr->{user_id},
                    favorited_expect => 1, retweeted_expect => 0,
                    remark_id => $remarks1[0]->id, remark_user_id => $remarks1[0]->user_id,
                    favorited => $remarks1[0]->favorited, retweeted => $remarks1[0]->retweeted,
                };

            # other Row::Status
            my $tweet2 = $class->single('status', { id => "239413543487819778" });

            # -> Row::User
            my $user2  = $tweet2->user; # belongs_to
            is $user2->screen_name, "twitterapi2", 'another profile';

            # -> Row::Remark
            is scalar @{[$tweet2->favorited]}, 0, '$tweet2 has no favorited'; # has_many
            is scalar @{[$tweet2->retweeted]}, 1, '$tweet2 has 1 retweeted'; # has_many
            my @remarks2 = $tweet2->remarked; # has_many
            is scalar @remarks2, 1, '$tweet2 has 1 remark';
            ok(!!(sprintf("%s", $remarks2[0]->user_id) eq "$attr->{user_id}" && ! $remarks2[0]->favorited && $remarks2[0]->retweeted),
                'another expected remark') or diag explain {
                    user_id => $attr->{user_id},
                    favorited_expect => 0, retweeted_expect => 1,
                    remark_id => $remarks2[0]->id, remark_user_id => $remarks2[0]->user_id,
                    favorited => $remarks2[0]->favorited, retweeted => $remarks2[0]->retweeted,
                };

        };

        subtest 'Row::User' => sub {
            plan tests => 7;

            # Row::User
            my $user = $class->single('user', { id => "6253282" });

            # -> Row::Status
            my @tweets1 = $user->tweets; # has_many
            is scalar @tweets1, 2, '$user1 has 2 tweets';

            # -> Row::Remark
            is scalar @{[$user->favorites]}, 2, '$user favorites 2 times'; # has_many
            is scalar @{[$user->retweets]},  2, '$user retweets 2 times'; # has_many
            is scalar @{[$user->remarks]},   3, '$user gives 3 remarks'; # has_many

            is scalar @{[$user->favorited]}, 1, '$user is favorited 1 time'; # has_many
            is scalar @{[$user->retweeted]}, 1, '$user is retweeted 1 time'; # has_many
            is scalar @{[$user->remarked]},  2, '$user takes 2 remarks'; # has_many
        };

        subtest 'Row::Remark' => sub {
            plan tests => 6;

            # Row::Remark
            my $remark1 = $class->single('remark', { id => "240859602684612608", user_id => "$attr->{user_id}" });

            # -> Row::Status
            # -> Row::User
            my $tweet1       = $remark1->tweet; # belongs_to
            my $user1        = $remark1->user;  # belongs_to
            my $status_user1 = $remark1->status_user;  # belongs_to
            is $tweet1->text, "Introducing the Twitter Certified Products Program: https://t.co/MjJ8xAnT", 'expected tweet (remark1)';
            is $user1->name, "Twitter API", 'expected user (remark1)';
            is $status_user1->name, "Twitter API", 'expected status_user (remark1)';

            # other Row::Remark
            my $remark2 = $class->single('remark', { id => "243014525132091393", user_id => "$attr->{user_id}" });

            # -> Row::Status
            # -> Row::User
            my $tweet2       = $remark2->tweet; # belongs_to
            my $user2        = $remark2->user;  # belongs_to
            my $status_user2 = $remark2->status_user;  # belongs_to
            is $tweet2->text, "Note to self:  don't die during off-peak hours on a holiday weekend.", 'expected tweet (remark2)';
            is $user2->name, "Twitter API", 'expected user (remark1)';
            is $status_user2->name, "Sean Cook", 'expected status_user (remark1)';
        };
    };
};

done_testing;
