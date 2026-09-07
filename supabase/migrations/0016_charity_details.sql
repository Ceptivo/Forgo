-- Forgo: richer charity profiles (logo, website, legal registration info,
-- and a "why we support them" message) + adds The Baby House Westville.
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0015.
--
-- Note: this deliberately does NOT add a "money raised so far" counter —
-- that's on hold pending a decision on how a specific forfeited stake
-- should be attributed to one charity vs another. charities.description
-- stays the short blurb shown in the list; why_we_support is the longer,
-- Forgo-authored paragraph shown on the charity's own detail page.

alter table public.charities
  add column if not exists logo_url text,
  add column if not exists website_url text,
  add column if not exists registration_info text,
  add column if not exists why_we_support text;

-- logo_url can be either a bundled Flutter asset path (e.g.
-- 'assets/images/charity_baby_house_westville.png' — requires the file to
-- exist in the app and a new build/release) or a plain https:// URL
-- (rendered with Image.network, no app update needed). The app tells
-- them apart by checking for an "http" prefix.

insert into public.charities (
  name, description, website_url, registration_info, why_we_support
)
select
  'The Baby House Westville',
  'A safe house in Westville, KwaZulu-Natal caring for abandoned and '
    'vulnerable babies until they are adopted into a loving home.',
  'https://www.thebabyhouse.co.za/',
  'NPO 153-305 · PBO 930050981 · Westville, KwaZulu-Natal, South Africa',
  'Every baby at The Baby House arrives with nothing and no one — often '
    'left with nowhere else to go. The team there gives each child round '
    'the clock care, medical attention, and a genuine home while they '
    'wait for an adoptive family to find them.' || E'\n\n' ||
    'We chose them as one of the charities behind Forgo because their '
    'work is immediate, tangible, and entirely dependent on people '
    'showing up for children who can''t yet advocate for themselves. '
    'When a goal on Forgo doesn''t get completed, a share of that stake '
    'goes toward keeping their doors open — so falling short of a '
    'personal goal still does some real good. If you''re able to, '
    'consider giving directly on their website too — every bit helps.'
where not exists (
  select 1 from public.charities where name = 'The Baby House Westville'
);

-- The logo is bundled at assets/images/charity_baby_house_westville.jpg —
-- point logo_url at it:
update public.charities
set logo_url = 'assets/images/charity_baby_house_westville.jpg'
where name = 'The Baby House Westville';
