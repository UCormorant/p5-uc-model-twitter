CREATE INDEX 'user_id_index' ON 'status' ('user_id','created_at');
ALTER TABLE 'remark' ADD COLUMN 'status_user_id' bigint NOT NULL;
