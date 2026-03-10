-- Init script for shared Temporal Postgres
-- Creates separate databases for each Postiz instance's Temporal server
-- Each instance gets its own DB + visibility DB for full isolation

CREATE DATABASE temporal_main;
CREATE DATABASE temporal_visibility_main;
CREATE DATABASE temporal_cc;
CREATE DATABASE temporal_visibility_cc;
CREATE DATABASE temporal_p2pf;
CREATE DATABASE temporal_visibility_p2pf;
