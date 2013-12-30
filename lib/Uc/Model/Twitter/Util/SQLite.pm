package Uc::Model::Twitter::Util::SQLite;

use 5.014;
use warnings;
use utf8;
use parent 'Exporter';

our @EXPORT = qw(
    create_table_sqlite
    drop_table_sqlite
);

our %SQL = (
    status        => q{
CREATE TABLE 'status' (
  'id'                      bigint      NOT NULL,
  'created_at'              datetime    NOT NULL DEFAULT '0000-00-00 00:00:00',
  'user_id'                 bigint      NOT NULL DEFAULT 0,
  'profile_id'              varchar(32) NOT NULL DEFAULT '',
  'text'                    text        NOT NULL,
  'source'                  text        DEFAULT NULL,
  'in_reply_to_status_id'   bigint      DEFAULT NULL,
  'in_reply_to_user_id'     bigint      DEFAULT NULL,
  'in_reply_to_screen_name' tinytext    DEFAULT NULL,
  'retweeted_status_id'     bigint      DEFAULT NULL,
  'protected'               boolean     DEFAULT NULL,
  'truncated'               boolean     DEFAULT NULL,
  'statuses_count'          int         DEFAULT NULL,
  'favourites_count'        int         DEFAULT NULL,
  'friends_count'           int         DEFAULT NULL,
  'followers_count'         int         DEFAULT NULL,
  'listed_count'            int         DEFAULT NULL,
  PRIMARY KEY ('id','created_at')
)
    },
    user          => q{
CREATE TABLE 'user' (
  'id'                                 bigint      NOT NULL,
  'profile_id'                         varchar(32) NOT NULL,
  'screen_name'                        tinytext    NOT NULL DEFAULT '',
  'name'                               tinytext    NOT NULL DEFAULT '',
  'location'                           tinytext    NOT NULL DEFAULT '',
  'url'                                tinytext    NOT NULL DEFAULT '',
  'description'                        text        NOT NULL DEFAULT '',
  'lang'                               tinytext    NOT NULL DEFAULT '',
  'time_zone'                          tinytext    NOT NULL DEFAULT '',
  'utc_offset'                         mediumint   NOT NULL DEFAULT 0,
  'profile_image_url'                  text        NOT NULL DEFAULT '',
  'profile_image_url_https'            text        NOT NULL DEFAULT '',
  'profile_background_image_url'       text        NOT NULL DEFAULT '',
  'profile_background_image_url_https' text        NOT NULL DEFAULT '',
  'profile_banner_url'                 text        NOT NULL DEFAULT '',
  'profile_text_color'                 varchar(8)  NOT NULL DEFAULT '',
  'profile_link_color'                 varchar(8)  NOT NULL DEFAULT '',
  'profile_background_color'           varchar(8)  NOT NULL DEFAULT '',
  'profile_sidebar_fill_color'         varchar(8)  NOT NULL DEFAULT '',
  'protected'                          boolean     NOT NULL DEFAULT 0,
  'geo_enabled'                        boolean     NOT NULL DEFAULT 0,
  'verified'                           boolean     NOT NULL DEFAULT 0,
  'is_translator'                      boolean     NOT NULL DEFAULT 0,
  'contributors_enabled'               boolean     NOT NULL DEFAULT 0,
  'default_profile'                    boolean     NOT NULL DEFAULT 0,
  'default_profile_image'              boolean     NOT NULL DEFAULT 0,
  'profile_use_background_image'       boolean     NOT NULL DEFAULT 0,
  'profile_background_tile'            boolean     NOT NULL DEFAULT 0,
  PRIMARY KEY ('id','profile_id')
)
    },
    remark        => q{
CREATE TABLE 'remark' (
  'id'        bigint  NOT NULL,
  'user_id'   bigint  NOT NULL,
  'favorited' boolean NOT NULL DEFAULT 0,
  'retweeted' boolean NOT NULL DEFAULT 0,
  PRIMARY KEY ('id','user_id')
)
    },
    profile_image => q{
CREATE TABLE 'profile_image' (
  'url'   text       NOT NULL,
  'image' mediumblob NOT NULL,
  PRIMARY KEY ('url')
)
    },
);

sub create_table_sqlite {
    my $class = shift;
    my %option = (
        if_not_exists => 1,
        @_,
    );

    my %sql = %SQL;
    if ($option{if_not_exists}) {
        my $dbh = $class->dbh;
        for my $table (keys %sql) {
            my $sth = $dbh->prepare(q{
                SELECT count(*) FROM sqlite_master
                    WHERE type='table' AND name=?;
            });
            $sth->execute($table);
            delete $sql{$table} if $sth->fetchrow_arrayref->[0];
        }
    }
    else {
        drop_table_sqlite($class);
    }

    $class->execute($sql{$_}) for keys %sql;
}

sub drop_table_sqlite {
    my $class = shift;
    $class->execute("DROP TABLE IF EXISTS $_") for scalar @_ ? @_ : keys %SQL;
}

1; # Magic true value required at end of module
