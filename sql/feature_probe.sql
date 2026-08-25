-- feature_probe.sql
-- Same probe, run against both containers. Diff the two output files and
-- whatever doesn't match is a genuine engine difference, not a guess.

\echo '--- 1. Engine identity -----------------------------------------'
SELECT version();

\echo '--- 2. Google / AlloyDB-specific extensions available -----------'
SELECT name, default_version, comment
FROM pg_available_extensions
WHERE name ILIKE 'google%'
   OR name ILIKE 'alloydb%'
   OR name ILIKE '%scann%'
   OR name ILIKE '%columnar%'
ORDER BY name;

\echo '--- 3. Extensions actually installed in this database ------------'
\dx

\echo '--- 4. vector search extensions available (pgvector etc.) --------'
SELECT name, default_version, comment
FROM pg_available_extensions
WHERE name ILIKE '%vector%'
ORDER BY name;

\echo '--- 5. Columnar-engine related GUCs (settings) --------------------'
SELECT name, setting, short_desc
FROM pg_settings
WHERE name ILIKE '%columnar%'
ORDER BY name;

\echo '--- 6. Autovacuum related GUCs (look for adaptive/auto-tuning) ----'
SELECT name, setting, short_desc
FROM pg_settings
WHERE name ILIKE '%autovacuum%'
ORDER BY name;

\echo '--- 7. Memory-management related GUCs ------------------------------'
SELECT name, setting, short_desc
FROM pg_settings
WHERE name ILIKE '%memory%'
ORDER BY name;

\echo '--- 8. Index-advisor related objects --------------------------------'
SELECT name, default_version, comment
FROM pg_available_extensions
WHERE name ILIKE '%advisor%' OR name ILIKE '%index%'
ORDER BY name;

\echo '--- 9. Full list of every available extension (for a manual diff) --'
SELECT name, default_version FROM pg_available_extensions ORDER BY name;
