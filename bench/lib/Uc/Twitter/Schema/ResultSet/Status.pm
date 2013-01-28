package Uc::Twitter::Schema::ResultSet::Status;

use common::sense;
use warnings qw(utf8);
use parent qw(DBIx::Class::ResultSet);
use Uc::Twitter::Schema::ResultSetBaseModule;

use Carp qw(croak);

our @BOOLEAN_VALUE = qw(
    protected
    truncated
);

sub find_or_create_from_tweet {
    my ($self, $tweet, $attr) = @_;
    my $result_source = $self->result_source;
    my $schema = $result_source->schema;
    my $user = $tweet->{user};

    croak "tweet must include user->{id} and user->{profile_id}" if not defined $user;

    my %columns;
    for my $col ($result_source->columns) {
        my $col_info = $result_source->column_info($col);
        $columns{$col} = $tweet->{$col} if     exists $tweet->{$col};
        $columns{$col} = $user->{$col}  if not exists $tweet->{$col} and exists $user->{$col};
        if (exists $columns{$col}) {
            if ($col ~~ \@BOOLEAN_VALUE) {
                $columns{$col} = 1 if $columns{$col} =~ /^true$/i;
                $columns{$col} = 0 if $columns{$col} =~ /^false$/i;
            }
        }
        elsif (not defined $columns{$col}) {
            if (!$col_info->{is_nullable}) {
                $columns{$col} = exists $col_info->{default_value} ? $col_info->{default_value} : '';
            }
        }

        $columns{$col} = format_datetime($columns{$col}, $col_info);
    }

    if (ref $tweet->{retweeted_status}) {
        $columns{retweeted_status_id} = $tweet->{retweeted_status}{id};

        $self->find_or_create_from_tweet($tweet->{retweeted_status}, $attr) if ref $tweet->{retweeted_status}{user};
    }

    if ($attr->{user_id} ne '') {
        my $update = {
            id => $tweet->{id},
            user_id => $attr->{user_id},
        };
        for my $col (qw/favorited retweeted/) {
            if ($tweet->{$col} =~ /\D/) {
                $update->{$col} = 1 if $tweet->{$col} =~ /^true$/i;
                $update->{$col} = 0 if $tweet->{$col} =~ /^false$/i;
            }
            else {
                $update->{$col} = $tweet->{$col};
            }
            delete $update->{$col} if $attr->{ignore_remark_disabling} && !$update->{$col};
        }
        if (exists $update->{favorited} or exists $update->{retweeted}) {
            $schema->resultset('Remark')->update_or_create_with_retweet($update);
        }
    }

    {
        my $profile = $schema->resultset('User')->find_or_create_from_user($user);
        $columns{user_id}    = $profile->id;
        $columns{profile_id} = $profile->profile_id;
        $columns{protected}  = $profile->protected;
    }

    $columns{$_} = deflate_utf8($columns{$_}) for $result_source->columns;

    $self->find_or_create(\%columns);
}

1;
