-- The leaderboard view must not expose profile emails or profile image data.
-- SECURITY INVOKER makes the caller's row-level security policies apply.
-- The current profiles policy limits reads to auth.uid() = id, so callers
-- can only see their own row through this view.

drop view if exists public.public_leaderboard;

create view public.public_leaderboard
with (security_invoker = true) as
select
  id,
  name,
  status,
  lifetime_fokus_tasks,
  coalesce((progress_data ->> 'local_user_points')::integer, 0) as total_points,
  coalesce((progress_data ->> 'local_user_fokus_minutes')::integer, 0) as fokus_minutes
from public.profiles
where auth.uid() is not null;

grant select on public.public_leaderboard to authenticated;
