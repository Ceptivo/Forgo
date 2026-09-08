-- Forgo: lock editing the Forgo Community's own name/bio/photo to the
-- founder only.
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0017.
--
-- Community settings now reuses the same GroupSettingsScreen every normal
-- group uses (name, bio, photo, members, goals) — see
-- lib/features/groups/presentation/screens/group_settings_screen.dart.
-- For a normal group, "any member can edit" is the right trust level
-- (same as sending a message). For the Forgo Community, every signed-in
-- user is auto-joined (0015_community.sql), so that same rule would let
-- literally anyone rebrand the app's own official space. Both places that
-- write a group's name/bio/photo — update_goal_group and the group_images
-- storage policies — now require public.is_forgo_founder() specifically
-- when the target is the community group; every other group is
-- unaffected.

create or replace function public.update_goal_group(
  p_group_id uuid,
  p_name text default null,
  p_bio text default null,
  p_image_url text default null
)
returns public.goal_groups
language plpgsql
security definer set search_path = public
as $$
declare
  v_group public.goal_groups;
begin
  if not public.is_goal_group_member(p_group_id) then
    raise exception 'Not a member of this group';
  end if;

  if p_group_id = '00000000-0000-0000-0000-000000000001'
    and not public.is_forgo_founder()
  then
    raise exception 'Only the founder can edit the Forgo Community';
  end if;

  update public.goal_groups
    set name = coalesce(nullif(trim(p_name), ''), name),
        bio = coalesce(p_bio, bio),
        image_url = coalesce(p_image_url, image_url)
    where id = p_group_id
    returning * into v_group;

  return v_group;
end;
$$;

drop policy if exists "Members can upload their group's image" on storage.objects;
create policy "Members can upload their group's image"
  on storage.objects for insert
  with check (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
    and (
      ((storage.foldername(name))[1])::uuid <> '00000000-0000-0000-0000-000000000001'
      or public.is_forgo_founder()
    )
  );

drop policy if exists "Members can update their group's image" on storage.objects;
create policy "Members can update their group's image"
  on storage.objects for update
  using (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
    and (
      ((storage.foldername(name))[1])::uuid <> '00000000-0000-0000-0000-000000000001'
      or public.is_forgo_founder()
    )
  );

drop policy if exists "Members can delete their group's image" on storage.objects;
create policy "Members can delete their group's image"
  on storage.objects for delete
  using (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
    and (
      ((storage.foldername(name))[1])::uuid <> '00000000-0000-0000-0000-000000000001'
      or public.is_forgo_founder()
    )
  );
