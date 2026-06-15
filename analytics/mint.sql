-- Mint per-site Umami website IDs (idempotent on domain).
-- Run: ssh netcup-full 'docker exec -i umami-db psql -U umami -d umami' < mint.sql
-- Admin user_id resolved dynamically so this stays portable.
\set ON_ERROR_STOP on

WITH admin AS (
  SELECT user_id FROM public."user" WHERE username = 'admin' AND deleted_at IS NULL LIMIT 1
),
seed(name, domain) AS (
  VALUES
    ('canvas-website',      'jeffemmett.com'),
    ('cadcad-website',      'cadcad.org'),
    ('the-last-draw',       'the-last-draw.cinesthesia.art'),
    ('cineasthesia-landing','cineasthesia.com'),
    ('cineasthesia-home',   'home.cineasthesia.com'),
    ('worldplay',           'worldplay.art'),
    ('dinner-worldplay',    'dinner.worldplay.art'),
    ('defectfi',            'defectfi.xyz'),
    ('cosmolocal',          'cosmolocal.world'),
    ('mycofi-earth',        'mycofi.earth'),
    ('mycrozine',           'zine.mycofi.earth'),
    ('jefflix',             'jefflix.lol'),
    ('ccg',                 'cryptocommonsgather.ing'),
    ('tino-ardez',          'tinoandri.ch'),
    ('elle-o-elle',         'elle-o-elle.lol'),
    ('compost-capitalism',  'compostcapitalism.xyz'),
    ('katheryn-mirror',     'mirror.katheryntrenshaw.com'),
    ('demos-jeffemmett',    'demos.jeffemmett.com'),
    ('relos-landing',       'relos.jeffemmett.com'),
    ('payment-forge',       'pay.jeffemmett.com'),
    ('p2pforum',            'forum.p2pfoundation.net'),
    ('forgejo-peer',        'forge-lab.jeffemmett.com')
)
INSERT INTO public.website (website_id, name, domain, user_id, created_by, created_at)
SELECT gen_random_uuid(), s.name, s.domain, a.user_id, a.user_id, CURRENT_TIMESTAMP
FROM seed s CROSS JOIN admin a
WHERE NOT EXISTS (
  SELECT 1 FROM public.website w
  WHERE w.domain = s.domain AND w.deleted_at IS NULL
);

-- Emit the full mapping (existing + newly minted) for the registry.
\pset format unaligned
\pset fieldsep '\t'
SELECT domain, website_id, name
FROM public.website
WHERE deleted_at IS NULL
  AND domain IN (
    'jeffemmett.com','cadcad.org','the-last-draw.cinesthesia.art','cineasthesia.com',
    'home.cineasthesia.com','worldplay.art','dinner.worldplay.art','defectfi.xyz',
    'cosmolocal.world','mycofi.earth','zine.mycofi.earth','jefflix.lol',
    'cryptocommonsgather.ing','tinoandri.ch','elle-o-elle.lol','compostcapitalism.xyz',
    'mirror.katheryntrenshaw.com','demos.jeffemmett.com','relos.jeffemmett.com',
    'pay.jeffemmett.com','forum.p2pfoundation.net','forge-lab.jeffemmett.com'
  )
ORDER BY name;
