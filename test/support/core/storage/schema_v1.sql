CREATE TABLE profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  seed TEXT NOT NULL
);
CREATE UNIQUE INDEX profiles_singleton ON profiles (1);
CREATE TABLE expenses (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0),
  category TEXT NOT NULL DEFAULT 'other' CHECK (length(category) > 0),
  description TEXT,
  occurred_on TEXT NOT NULL CHECK (
    length(occurred_on) = 10
    AND occurred_on >= '0001-01-01'
    AND occurred_on <= '9999-12-31'
    AND date(occurred_on, '+0 days') IS NOT NULL
    AND date(occurred_on, '+0 days') = occurred_on
  )
);
CREATE INDEX expenses_profile_date ON expenses (profile_id, occurred_on, id);
PRAGMA user_version = 1;
