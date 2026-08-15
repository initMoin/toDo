
  create table "public"."devices" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "platform" text not null,
    "push_token" text not null,
    "timezone" text not null default 'UTC'::text,
    "last_seen_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."devices" enable row level security;


  create table "public"."notification_preferences" (
    "user_id" uuid not null,
    "reminders_enabled" boolean not null default true,
    "quiet_hours_start" time without time zone,
    "quiet_hours_end" time without time zone,
    "timezone" text not null default 'UTC'::text,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."notification_preferences" enable row level security;


  create table "public"."profiles" (
    "id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "display_name" text,
    "timezone" text not null default 'UTC'::text
      );


alter table "public"."profiles" enable row level security;


  create table "public"."todos" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "missive" text not null,
    "notes" text,
    "is_done" boolean not null default false,
    "due_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."todos" enable row level security;

CREATE UNIQUE INDEX devices_pkey ON public.devices USING btree (id);

CREATE UNIQUE INDEX notification_preferences_pkey ON public.notification_preferences USING btree (user_id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX todos_pkey ON public.todos USING btree (id);

alter table "public"."devices" add constraint "devices_pkey" PRIMARY KEY using index "devices_pkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_pkey" PRIMARY KEY using index "notification_preferences_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."todos" add constraint "todos_pkey" PRIMARY KEY using index "todos_pkey";

alter table "public"."devices" add constraint "devices_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."devices" validate constraint "devices_user_id_fkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."notification_preferences" validate constraint "notification_preferences_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."todos" add constraint "todos_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."todos" validate constraint "todos_user_id_fkey";

grant delete on table "public"."devices" to "anon";

grant insert on table "public"."devices" to "anon";

grant references on table "public"."devices" to "anon";

grant select on table "public"."devices" to "anon";

grant trigger on table "public"."devices" to "anon";

grant truncate on table "public"."devices" to "anon";

grant update on table "public"."devices" to "anon";

grant delete on table "public"."devices" to "authenticated";

grant insert on table "public"."devices" to "authenticated";

grant references on table "public"."devices" to "authenticated";

grant select on table "public"."devices" to "authenticated";

grant trigger on table "public"."devices" to "authenticated";

grant truncate on table "public"."devices" to "authenticated";

grant update on table "public"."devices" to "authenticated";

grant delete on table "public"."devices" to "service_role";

grant insert on table "public"."devices" to "service_role";

grant references on table "public"."devices" to "service_role";

grant select on table "public"."devices" to "service_role";

grant trigger on table "public"."devices" to "service_role";

grant truncate on table "public"."devices" to "service_role";

grant update on table "public"."devices" to "service_role";

grant delete on table "public"."notification_preferences" to "anon";

grant insert on table "public"."notification_preferences" to "anon";

grant references on table "public"."notification_preferences" to "anon";

grant select on table "public"."notification_preferences" to "anon";

grant trigger on table "public"."notification_preferences" to "anon";

grant truncate on table "public"."notification_preferences" to "anon";

grant update on table "public"."notification_preferences" to "anon";

grant delete on table "public"."notification_preferences" to "authenticated";

grant insert on table "public"."notification_preferences" to "authenticated";

grant references on table "public"."notification_preferences" to "authenticated";

grant select on table "public"."notification_preferences" to "authenticated";

grant trigger on table "public"."notification_preferences" to "authenticated";

grant truncate on table "public"."notification_preferences" to "authenticated";

grant update on table "public"."notification_preferences" to "authenticated";

grant delete on table "public"."notification_preferences" to "service_role";

grant insert on table "public"."notification_preferences" to "service_role";

grant references on table "public"."notification_preferences" to "service_role";

grant select on table "public"."notification_preferences" to "service_role";

grant trigger on table "public"."notification_preferences" to "service_role";

grant truncate on table "public"."notification_preferences" to "service_role";

grant update on table "public"."notification_preferences" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."todos" to "anon";

grant insert on table "public"."todos" to "anon";

grant references on table "public"."todos" to "anon";

grant select on table "public"."todos" to "anon";

grant trigger on table "public"."todos" to "anon";

grant truncate on table "public"."todos" to "anon";

grant update on table "public"."todos" to "anon";

grant delete on table "public"."todos" to "authenticated";

grant insert on table "public"."todos" to "authenticated";

grant references on table "public"."todos" to "authenticated";

grant select on table "public"."todos" to "authenticated";

grant trigger on table "public"."todos" to "authenticated";

grant truncate on table "public"."todos" to "authenticated";

grant update on table "public"."todos" to "authenticated";

grant delete on table "public"."todos" to "service_role";

grant insert on table "public"."todos" to "service_role";

grant references on table "public"."todos" to "service_role";

grant select on table "public"."todos" to "service_role";

grant trigger on table "public"."todos" to "service_role";

grant truncate on table "public"."todos" to "service_role";

grant update on table "public"."todos" to "service_role";


  create policy "Users can delete own devices"
  on "public"."devices"
  as permissive
  for delete
  to authenticated
using ((auth.uid() = user_id));



  create policy "Users can insert own devices"
  on "public"."devices"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "Users can update own devices"
  on "public"."devices"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own devices"
  on "public"."devices"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "Users can insert own notification preferences"
  on "public"."notification_preferences"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "Users can update own notification preferences"
  on "public"."notification_preferences"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own notification preferences"
  on "public"."notification_preferences"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "Users can insert own profile"
  on "public"."profiles"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = id));



  create policy "Users can update own profile"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((auth.uid() = id))
with check ((auth.uid() = id));



  create policy "Users can view own profile"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using ((auth.uid() = id));



  create policy "Users can delete own todos"
  on "public"."todos"
  as permissive
  for delete
  to authenticated
using ((auth.uid() = user_id));



  create policy "Users can insert own todos"
  on "public"."todos"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "Users can update own todos"
  on "public"."todos"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own todos"
  on "public"."todos"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



