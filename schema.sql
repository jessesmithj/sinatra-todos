-- Execute database 
-- psql -d todos < schema.sql

CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE CHECK (length(name) >= 1) 
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL CHECK (length(name) >= 1),
  complete boolean NOT NULL DEFAULT false,
  list_id int NOT NULL REFERENCES lists (id) ON DELETE CASCADE 
);