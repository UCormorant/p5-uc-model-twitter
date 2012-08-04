package Uc::Twitter::Schema::ResultSet::Status;

use common::sense;
use warnings qw(utf8);
use parent 'DBIx::Class::ResultSet';

use Carp qw(croak);
use Encode qw(encode_utf8);
use DateTime::Format::HTTP;

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
        $columns{$col} = $tweet->{$col} if     exists $tweet->{$col};
        $columns{$col} = $user->{$col}  if not exists $tweet->{$col} and exists $user->{$col};
        if (exists $columns{$col} && $col ~~ \@BOOLEAN_VALUE) {
            $columns{$col} = 1 if $columns{$col} =~ /^true$/i;
            $columns{$col} = 0 if $columns{$col} =~ /^false$/i;
        }
        elsif (not defined $columns{$col}) {
            my $col_info = $result_source->column_info($col);
            if (!$col_info->{is_nullable}) {
                $columns{$col} = exists $col_info->{default_value} ? $col_info->{default_value} : '';
            }
        }
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
            $schema->resultset('Remark')->update_or_create($update);
        }
    }

    {
        my $profile = $schema->resultset('User')->find_or_create_from_user($user);
        $columns{user_id}    = $profile->id;
        $columns{profile_id} = $profile->profile_id;
        $columns{protected}  = $profile->protected;
    }

    for my $col ($result_source->columns) {
        $columns{$col} = encode_utf8($columns{$col}) if exists $columns{$col} && utf8::is_utf8($columns{$col});
    }

    if (ref $columns{created_at} ne 'DateTime') {
        $columns{created_at} =~ s/\+0000/GMT/;
        $columns{created_at} = DateTime::Format::HTTP->parse_datetime($columns{created_at});
    }

    $self->find_or_create(\%columns);
}

1;
