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

See ["lib/Uc/Model/Twitter/Schema.pm"](#lib/Uc/Model/Twitter/Schema.pm).

# METHODS

- `$tweet_row = $umt->find_or_create_status($tweet, [$attr])`

    Find or create a row into `status` table.
    Returns the inserted row object.

    `$attr` can include:

    - `user_id`

        An numeric id of the user who receive `$tweet`.

    - `ignore_unmarking`

        If this is given, `update_or_create_remark` ignores false values when update `remark` table rows.

    - `retweeted_status`

        If this is given, `update_or_create_remark` uses `$attr->{retweeted_status}{id}` as retweet status id.
        Or, it will do `$umt->find_or_create_status($tweet->{retweeted_status})` and get the status id from returned value.

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
        favorited => true or false,
        retweeted => true or false,

- `$umt->create_table([$option])`

    Initialize database schema.
    !!!If you call this method, all table rows will be deleted!!!

    `$option->{if_not_exists}` is available.

- `$umt->drop_table([$table, $table, ...])`

    Drop tables (status, user, remark and profile\_images).

# DEPENDENCIES

- [perl](http://search.cpan.org/perldoc?perl) >= 5.14
- [Teng](http://search.cpan.org/perldoc?Teng)
- Teng::Plugin::DBIC::ResultSet

    [https://github.com/UCormorant/p5-teng-plugin-dbic-resultset](https://github.com/UCormorant/p5-teng-plugin-dbic-resultset)

- [DateTime::Format::HTTP](http://search.cpan.org/perldoc?DateTime::Format::HTTP)
- [DateTime::Format::MySQL](http://search.cpan.org/perldoc?DateTime::Format::MySQL)

# BUGS AND LIMITATIONS

Please report any bugs or feature requests to
[https://github.com/UCormorant/p5-uc-model-twitter/issues](https://github.com/UCormorant/p5-uc-model-twitter/issues)

# AUTHOR

U=Cormorant <u@chimata.org>

# LICENSE

Copyright (C) U=Cormorant.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](http://search.cpan.org/perldoc?perlartistic).
