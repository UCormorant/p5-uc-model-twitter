use t::Util;
use Test::More;
use Test::More::Hooks;

use Uc::Model::Twitter;
Uc::Model::Twitter->load_plugin('Count');

BEGIN {
    eval "use DBD::mysql";
    if ($@) {
        plan skip_all => 'test requires DBD::mysql for testing';
    }
    else {
        plan tests => 1;
    }
}

my $DB_HANDLE = eval {t::Util->setup_mysql_dbh()};
if ($@) { fail 'mysql setup error'; }

subtest "mysql test" => sub {
    my $class;
    before { $class = Uc::Model::Twitter->new( dbh => $DB_HANDLE ); };
    after  { undef $class; };

    plan tests => 2;

    subtest "connect and setup database" => sub {
        plan tests => 3;
        isa_ok $class, 'Uc::Model::Twitter', '$class';

        subtest "create and drop table" => sub {
            plan tests => 2;
            my($sth, @got);
            my $table_name = 'uc_model_twitter';
            my %expect = (profile_image => 1, remark => 1, status => 1, user => 1, $table_name => 0);

            $class->do(qq{DROP TABLE IF EXISTS $table_name});
            $class->create_table;

            $expect{$table_name} = 0; # expect '$table_name' is dropped
            $sth = $class->execute(q{SHOW TABLES});
            @got = sort grep { exists $expect{$_} } map { $_->[0] } @{$sth->fetchall_arrayref};
            is_deeply \@got, [sort grep { $expect{$_} } keys %expect], '4 tables are created';

            # create other table
            $class->do(qq{CREATE TABLE $table_name (id int primary key, value text)});
            $class->drop_table;

            $expect{$table_name} = 1; # expect '$table_name' is not dropped
            $sth = $class->execute(q{SHOW TABLES});
            @got = grep { exists $expect{$_} } map { $_->[0] } @{$sth->fetchall_arrayref};
            ok !!(scalar @got == 1 && $got[0] eq $table_name), '4 tables are dropped';

            $class->do(qq{DROP TABLE IF EXISTS $table_name});
        };

        subtest "create_table with if_not_exists" => sub {
            plan tests => 3;
            my($sth, @got);
            my $drop_table = 'user';
            my %expect = (profile_image => 1, remark => 1, status => 1, user => 0);

            # force create table
            $class->create_table(if_not_exists => 0);

            # insert rows into 'status'
            my $status = t::Util->open_json_file('t/status.exclude_retweet.json');
            my $tweet = $class->find_or_create_status($status);

            # drop table 'user'
            $class->drop_table($drop_table);

            $expect{user} = 0; # expect 'user' is dropped
            $sth = $class->execute(q{SHOW TABLES});
            @got = sort grep { exists $expect{$_} } map { $_->[0] } @{$sth->fetchall_arrayref};
            is_deeply \@got, [sort grep { $expect{$_} } keys %expect], '3 tables are created';

            # create dropped table 'user'
            $class->create_table();

            $expect{user} = 1; # expect 'user' is created
            $sth = $class->execute(q{SHOW TABLES});
            @got = sort grep { exists $expect{$_} } map { $_->[0] } @{$sth->fetchall_arrayref};
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

        plan tests => 5;

        subtest "find_or_create_profile" => sub {
            plan tests => 7;

            can_ok $class, 'find_or_create_profile';

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

        subtest "find_or_create_status" => sub {
            plan tests => 6;

            can_ok $class, 'find_or_create_status';

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
            ok !!($tweet1->id eq $tweet2->id and $tweet1->id eq $tweet3->id), 'searching with a same id retuerns same row';
        };

        subtest "find_or_create_status (with retweet)" => sub {
            plan tests => 9;

            can_ok $class, 'find_or_create_status';

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
            ok !!($tweet1->id eq $tweet2->id and $tweet1->id eq $tweet3->id), 'searching with a same id retuerns same row';

            # get original tweet
            my $tweet_orig = $class->single('status', { id => $tweet1->retweeted_status_id });
            isa_ok $tweet_orig, 'Uc::Model::Twitter::Row::Status', 'retval of find a original tweet by id';

            # check relation
            ok $tweet1->retweeted_status_id eq $tweet_orig->id, 'check relation';
        };

        subtest "update_or_create_remark" => sub {
            plan tests => 8;

            can_ok $class, 'update_or_create_remark';

            # get tweet with retweet
            my $status = t::Util->open_json_file('t/status.include_retweet.json');

            my $tweet = $class->find_or_create_status($status);
            isa_ok $tweet, 'Uc::Model::Twitter::Row::Status', 'retval of create a status with retweet';

            # target is original tweet
            my %update = (
                id => $tweet->retweeted_status_id,
                user_id => $tweet->user_id,
            );

            # mark as retweeted status
            $update{retweeted} = 1;

            my $remark1 = $class->update_or_create_remark(\%update);
            isa_ok $remark1, 'Uc::Model::Twitter::Row::Remark', 'retval of mark as retweeted status';

            ok $remark1->retweeted, 'target tweet is marked as retweeted status';
            ok !!($remark1->id == $tweet->retweeted_status_id and $remark1->user_id == $tweet->user_id),
                'check relation';

            # unmark as retweeted and mark as favorited
            $update{retweeted} = 0;
            $update{favorited} = 1;

            my $remark2 = $class->update_or_create_remark(\%update);
            isa_ok $remark2, 'Uc::Model::Twitter::Row::Remark', 'retval of update remarks';

            ok ! $remark2->retweeted, 'target is unretweeted';
            ok   $remark2->favorited, 'target is favorited';
        };

        subtest "update_or_create_remark (with retweet)" => sub {
            plan tests => 12;

            can_ok $class, 'update_or_create_remark';

            # get tweet with retweet
            my $status = t::Util->open_json_file('t/status.include_retweet.json');

            my $tweet = $class->find_or_create_status($status);
            isa_ok $tweet, 'Uc::Model::Twitter::Row::Status', 'retval of create a status with retweet';

            # retweet 'RT status'
            my %update = (
                id => $tweet->id,
                user_id => $tweet->user_id,
            );
            $update{retweeted} = 1;

            my $remark1 = $class->update_or_create_remark(
                \%update,
                { retweeted_status => $status->{retweeted_status} }
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
    };
};

done_testing;
