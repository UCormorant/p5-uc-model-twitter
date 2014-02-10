package Uc::Model::Twitter v1.2.2;

use 5.014;
use warnings;
use utf8;
use experimental qw(smartmatch);

use parent 'Teng';
__PACKAGE__->load_plugin('DBIC::ResultSet');

use Carp qw(croak);
use DBI qw(:sql_types);
use Uc::Model::Twitter::Util;
use autouse 'Uc::Model::Twitter::Util::MySQL'  => qw(create_table_mysql  drop_table_mysql );
use autouse 'Uc::Model::Twitter::Util::SQLite' => qw(create_table_sqlite drop_table_sqlite);

use namespace::clean;

sub find_or_create_status {
    my ($self, $tweet, $attr) = @_;
    my $table = $self->schema->get_table('status');
    my $user  = $tweet->{user};

    $attr = +{} unless $attr;
    $attr->{user_id}          = '' if not exists $attr->{user_id};
    $attr->{ignore_unmarking} = '' if not exists $attr->{ignore_unmarking};

    croak "each tweet must contain tweet's user object" if not defined $user;

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $tweet->{$col} if     exists $tweet->{$col};
        $columns{$col} = $user->{$col}  if not exists $tweet->{$col} and exists $user->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }

    if (ref $tweet->{retweeted_status}) {
        $columns{retweeted_status_id} = $tweet->{retweeted_status}{id};

        $self->find_or_create_status($tweet->{retweeted_status}, $attr) if ref $tweet->{retweeted_status}{user};
    }
    elsif ($attr->{user_id} ne '') {
        my %update = (
            id => $tweet->{id},
            user_id => $attr->{user_id},
            status_user_id => $tweet->{user}{id},
        );
        my $table_remark = $self->schema->get_table('remark');
        my $sql_types = $table_remark->sql_types;
        my @boolean_cols;
        for my $col (keys $sql_types) {
            if (exists $tweet->{$col} && $sql_types->{$col} == SQL_BOOLEAN) {
                push @boolean_cols, $col;
                $update{$col} = boolify($tweet->{$col});
                delete $update{$col} if $attr->{ignore_unmarking} && !$update{$col};
            }
        }
        if (scalar grep { exists $update{$_} } @boolean_cols) {
            $self->update_or_create_remark(\%update);
        }
    }

    {
        my $profile = $self->find_or_create_profile($user);
        $columns{user_id}    = $profile->id;
        $columns{profile_id} = $profile->profile_id;
        $columns{protected}  = $profile->protected;
    }

    for my $col (keys %columns) {
        $columns{$col} = format_datetime($columns{$col}) if $table->get_sql_type($col) == SQL_DATETIME;
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    $self->find_or_create('status', \%columns);
}

sub find_or_create_profile {
    my ($self, $user, $attr) = @_;
    my $table = $self->schema->get_table('user');

    $attr = +{} unless $attr;

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $user->{$col} if exists $user->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }
    $columns{profile_id} = get_profile_id($user, $table) if !$columns{profile_id};

    %columns = %{user_default_value(\%columns, $table)};
    for my $col (@{$table->columns}) {
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    $self->find_or_create('user', \%columns);
}

sub update_or_create_remark {
    my ($self, $update, $attr) = @_;
    my $table = $self->schema->get_table('remark');

    $attr = +{} unless $attr;
    $attr->{retweeted_status_id}      = '' if not exists $attr->{retweeted_status_id};
    $attr->{retweeted_status_user_id} = '' if not exists $attr->{retweeted_status_user_id};

    croak "first argument must be included id and user_id" if !$update->{id} or !$update->{user_id};

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $update->{$col} if exists $update->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }

    for my $col (keys %columns) {
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    my $retweeted_status_id = undef;
    my $retweeted_status_user_id = undef;
    if ($attr->{retweeted_status_id} ne '') {
        $retweeted_status_id = $attr->{retweeted_status_id};
    }
    else {
        my $tweet = $self->single('status', +{ id => $columns{id} });
        if ($tweet and defined $tweet->retweeted_status_id and $tweet->retweeted_status_id ne '') {
            $retweeted_status_id = $tweet->retweeted_status_id;
        }
    }

    if ($attr->{retweeted_status_user_id} ne '') {
        $retweeted_status_user_id = $attr->{retweeted_status_user_id};
    }
    elsif (defined $retweeted_status_id) {
        my $tweet = $self->single('status', +{ id => $retweeted_status_id });
        $retweeted_status_user_id = $tweet->user_id if $tweet;
    }

    if (defined $retweeted_status_id and defined $retweeted_status_user_id) {
        my %retweet_update = %columns;
        $retweet_update{id} = numify($retweeted_status_id);
        $retweet_update{status_user_id} = numify($retweeted_status_user_id);
        $self->update_or_create('remark', \%retweet_update);
    }

    $self->update_or_create('remark', \%columns);
}

sub create_table {
    given ($_[0]->dbh->{Driver}{Name}) {
        when ('SQLite') { create_table_sqlite(@_); }
        when ('mysql')  { create_table_mysql(@_); }
        default         { croak "'$_' is not supported."; }
    }
}

sub drop_table {
    given ($_[0]->dbh->{Driver}{Name}) {
        when ('SQLite') { drop_table_sqlite(@_); }
        when ('mysql')  { drop_table_mysql(@_); }
        default         { croak "'$_' is not supported."; }
    }
}

1; # Magic true value required at end of module
__END__

=encoding utf-8

=head1 NAME

Uc::Model::Twitter - Teng model class for tweet

=head1 SYNOPSIS

    use Uc::Model::Twitter;

    my $umt = Uc::Model::Twitter->new(
        connect_info => ['dbi:mysql:twitter', 'root', '****', {
            mysql_enable_utf8 => 1,
            on_connect_do     => ['set names utf8mb4'],
    }]);

    # $umt is Teng object. enjoy!

=head1 DESCRIPTION

Uc::Model::Twitter is the teng model class for Twitter's tweets.

=head1 TABLE

See L</lib/Uc/Model/Twitter/Schema.pm>.

=head1 METHODS

=over 2

=item C<< $tweet_row = $umt->find_or_create_status($tweet, [$attr]) >>

Find or create a row into C<status> table.
Returns the inserted row object.

If C<$tweet> includeds C<< $tweet->{retweeted_status} >>,
it will also be stored into the database automatically.

C<$attr> can include:

=over

=item * C<user_id>

An numeric id of the user who receive C<$tweet>.

=item * C<ignore_unmarking>

If this is given, C<update_or_create_remark> ignores false values when update C<remark> table rows.

=back

If C<$tweet> has C<user>, it calls C<find_or_create_profile> too.
A profile row will be created whenever user profile update will come.

When a row is inserted and C<< $attr->{user_id} >> is geven,
you also call C<update_or_create_remark> automatically.

=item C<< $profile_row = $umt->find_or_create_profile($user, [$attr]) >>

Find or create a row into C<user> table.
Returns the inserted row object.

Profile rows is just user profile, not user object, so one user has many profile rows.

=item C<< $remark_row = $umt->update_or_create_remark($remark, [$attr]) >>

Update or create a row into C<remark> table.
Returns the updated row object.

You should give this method the hash reference as C<$remark> that include following values.

    id => tweet id,
    user_id => event user id,
    status_user_id => tweet's user id,
    favorited => true or false,
    retweeted => true or false,

=item C<< $umt->create_table([$option]) >>

Create tables if not exists.

If you want to initialize database, call with C<< $option->{if_not_exists} = 0 >>.
B<!!!If you call this method with C<< $option->{if_not_exists} = 0 >>, all tables rows will be deleted!!!>

=item C<< $umt->drop_table([$table, $table, ...]) >>

Drop tables (status, user, remark and profile_images).

=back

=head1 DEPENDENCIES

=over 2

=item L<perl> >= 5.14

=item L<experimental>

=item L<namespace::clean>

=item L<Teng>

=item Teng::Plugin::DBIC::ResultSet

L<https://github.com/UCormorant/p5-teng-plugin-dbic-resultset>

=item L<DateTime::Format::HTTP>

=item L<DateTime::Format::MySQL>

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
L<https://github.com/UCormorant/p5-uc-model-twitter/issues>

=head1 AUTHOR

U=Cormorant E<lt>u@chimata.orgE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) U=Cormorant.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
