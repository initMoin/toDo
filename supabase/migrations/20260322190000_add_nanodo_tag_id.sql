do $$
begin
  if to_regclass('public.nanodos') is not null
     and to_regclass('public.tags') is not null then
    execute '
      alter table public.nanodos
      add column if not exists tag_id uuid
      references public.tags(id)
      on delete set null
    ';

    execute '
      create index if not exists nanodos_tag_id_idx
      on public.nanodos(tag_id)
    ';
  end if;
end
$$;