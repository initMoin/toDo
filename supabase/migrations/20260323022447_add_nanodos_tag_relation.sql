alter table public.nanodos
add column if not exists tag_id uuid references public.tags(id) on delete set null;

create index if not exists nanodos_tag_id_idx
on public.nanodos(tag_id);