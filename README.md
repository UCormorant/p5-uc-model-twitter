[![Build Status](https://travis-ci.org/UCormorant/p5-uc-model-twitter.png?branch=master)](https://travis-ci.org/UCormorant/p5-uc-model-twitter) [![Coverage Status](https://coveralls.io/repos/UCormorant/p5-uc-model-twitter/badge.png?branch=master)](https://coveralls.io/r/UCormorant/p5-uc-model-twitter?branch=master)
# NAME

Uc::Model::Twitter - Teng model class for tweet

# SYNOPSIS

    use Uc::Model::Twitter;

    my $umt = Uc::Model::Twitter->new(
        connect_info => ['dbi:mysql:twitter', 'root', '****', {
            mysql_enable_utf8 => 1,
            on_connect_do     => ['set names utf8mb4'],
    }]);

    # $umt is Teng object. enjoy!

# DESCRIPTION

Uc::Model::Twitter is the teng model class for Twitter's tweets.

# TABLE

See ["lib/Uc/Model/Twitter/Schema.pm"](#lib-uc-model-twitter-schema-pm).

# METHODS

- `$tweet_row = $umt->find_or_create_status($tweet, [$attr])`

    Find or create a row into `status` table.
    Returns the inserted row object.

    If `$tweet` includeds `$tweet->{retweeted_status}`,
    it will also be stored into the database automatically.

    `$attr` can include:

    - `user_id`

        An numeric id of the user who receive `$tweet`.

    - `ignore_unmarking`

        If this is given, `update_or_create_remark` ignores false values when update `remark` table rows.

    If `$tweet` has `user`, it calls `find_or_create_profile` too.
    A profile row will be created whenever user profile update will come.

    When a row is inserted and `$attr->{user_id}` is geven,
    you also call `update_or_create_remark` automatically.

- `$profile_row = $umt->find_or_create_profile($user, [$attr])`

    Find or create a row into `user` table.
    Returns the inserted row object.

    Profile rows is just user profile, not user object, so one user has many profile rows.

- `$remark_row = $umt->update_or_create_remark($remark, [$attr])`

    Update or create a row into `remark` table.
    Returns the updated row object.

    You should give this method the hash reference as `$remark` that include following values.

        id => tweet id,
        user_id => event user id,
        status_user_id => tweet's user id,
        favorited => true or false,
        retweeted => true or false,

- `$umt->create_table([$option])`

    Create tables if not exists.

    If you want to initialize database, call with `$option->{if_not_exists} = 0`.
    __!!!If you call this method with `$option->{if_not_exists} = 0`, all tables rows will be deleted!!!__

- `$umt->drop_table([$table, $table, ...])`

    Drop tables (status, user, remark and profile\_images).

# DEPENDENCIES

- [perl](https://metacpan.org/pod/perl) >= 5.14
- [experimental](https://metacpan.org/pod/experimental)
- [namespace::clean](https://metacpan.org/pod/namespace::clean)
- [Teng](https://metacpan.org/pod/Teng)
- Teng::Plugin::DBIC::ResultSet

    [https://github.com/UCormorant/p5-teng-plugin-dbic-resultset](https://github.com/UCormorant/p5-teng-plugin-dbic-resultset)

- [DateTime::Format::HTTP](https://metacpan.org/pod/DateTime::Format::HTTP)
- [DateTime::Format::MySQL](https://metacpan.org/pod/DateTime::Format::MySQL)

# BUGS AND LIMITATIONS

Please report any bugs or feature requests to
[https://github.com/UCormorant/p5-uc-model-twitter/issues](https://github.com/UCormorant/p5-uc-model-twitter/issues)

# AUTHOR

U=Cormorant <u@chimata.org>

# LICENCE AND COPYRIGHT

Copyright (C) U=Cormorant.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).
