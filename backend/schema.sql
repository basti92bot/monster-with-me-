create schema mwm_private;
revoke all on schema mwm_private from public, anon;
grant usage on schema mwm_private to authenticated;
create table mwm_private.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null default 'Du' check(char_length(name) between 1 and 30),
 goal integer not null default 500 check(goal between 250 and 3000),
 invite text not null unique default left(replace(gen_random_uuid()::text,'-',''),24)
);
create table mwm_private.drinks (
 id uuid primary key, user_id uuid not null references mwm_private.profiles(id) on delete cascade,
 kind text not null check(kind in ('Monster Energy','Monster Ultra White','Monster Mango Loco','Monster Pipeline Punch','Monster Zero Sugar','Monster Lando Norris','Monster Lewis Hamilton')),
 amount integer not null check(amount between 1 and 3000),
 day date not null default (now() at time zone 'Europe/Berlin')::date,
 created_at timestamptz not null default now()
);
create index mwm_drinks_user_day_time on mwm_private.drinks(user_id,day,created_at desc);
create table mwm_private.friends (
 user_id uuid not null references mwm_private.profiles(id) on delete cascade,
 friend_id uuid not null references mwm_private.profiles(id) on delete cascade,
 primary key(user_id,friend_id),check(user_id<>friend_id)
);
create table mwm_private.cheers (
 drink_id uuid not null references mwm_private.drinks(id) on delete cascade,
 sender_id uuid not null references mwm_private.profiles(id) on delete cascade,
 primary key(drink_id,sender_id)
);
alter table mwm_private.profiles enable row level security;
alter table mwm_private.drinks enable row level security;
alter table mwm_private.friends enable row level security;
alter table mwm_private.cheers enable row level security;
revoke all on all tables in schema mwm_private from public,anon,authenticated;
-- Client roles have no direct table access. Private functions enforce ownership and friendship.
create function mwm_private.state() returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'Europe/Berlin')::date; result jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into mwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 select jsonb_build_object(
 'profile',(select jsonb_build_object('name',name,'goal',goal,'invite',invite) from mwm_private.profiles where id=uid),
 'today',today::text,
 'entries',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000),'cheers',(select count(*) from mwm_private.cheers c where c.drink_id=d.id)) order by d.created_at desc) from mwm_private.drinks d where d.user_id=uid and d.day=today),'[]'::jsonb),
 'week',(select jsonb_agg(jsonb_build_object('day',day::text,'total',coalesce(total,0)) order by day) from (
   select today-g.i as day,(select sum(amount) from mwm_private.drinks where user_id=uid and day=today-g.i) as total from generate_series(0,6) g(i)
 ) w),
 'friends',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'goal',p.goal,'total',coalesce(t.total,0),'drink_id',d.id,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000),'cheered',case when exists(select 1 from mwm_private.cheers c where c.drink_id=d.id and c.sender_id=uid) then 1 else 0 end) order by d.created_at desc nulls last)
 from mwm_private.friends f join mwm_private.profiles p on p.id=f.friend_id
 left join lateral(select sum(amount) total from mwm_private.drinks where user_id=p.id and day=today) t on true
 left join lateral(select * from mwm_private.drinks where user_id=p.id order by created_at desc limit 1) d on true
 where f.user_id=uid),'[]'::jsonb)
 ) into result;
 return result;
end $$;
create function mwm_private.action(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); target uuid; entry uuid; action text:=payload->>'action'; amount integer; new_goal integer; new_name text;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into mwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 if action='drink' then
   if coalesce(payload->>'kind','') not in ('Monster Energy','Monster Ultra White','Monster Mango Loco','Monster Pipeline Punch','Monster Zero Sugar','Monster Lando Norris','Monster Lewis Hamilton') or coalesce(payload->>'amount','') !~ '^[0-9]{1,4}$' then raise exception 'Ungültiges Getränk oder Menge.';end if;
   amount:=(payload->>'amount')::integer;entry:=(payload->>'id')::uuid;
   if amount<1 or amount>3000 or entry is null then raise exception 'Bitte 1 bis 3.000 ml wählen.';end if;
   if exists(select 1 from mwm_private.drinks where id=entry and user_id<>uid) then raise exception 'Eintrag gehört nicht zu dir.' using errcode='42501';end if;
   insert into mwm_private.drinks(id,user_id,kind,amount) values(entry,uid,payload->>'kind',amount) on conflict(id) do nothing;
 elsif action='delete' then
   delete from mwm_private.drinks where id=(payload->>'id')::uuid and user_id=uid;
 elsif action='profile' then
   new_name:=trim(payload->>'name');
   if coalesce(payload->>'goal','') !~ '^[0-9]{3,4}$' or new_name is null or char_length(new_name) not between 1 and 30 then raise exception 'Bitte Name und Tageslimit prüfen.';end if;
   new_goal:=(payload->>'goal')::integer;if new_goal not between 250 and 3000 then raise exception 'Tageslimit: 250 bis 3.000 ml.';end if;
   update mwm_private.profiles set name=new_name,goal=new_goal where id=uid;
 elsif action='friend' then
   select id into target from mwm_private.profiles where invite=lower(trim(payload->>'code'));
   if target is null or target=uid then raise exception 'Kein gültiger Freundescode.';end if;
   insert into mwm_private.friends(user_id,friend_id) values(uid,target),(target,uid) on conflict do nothing;
 elsif action='unfriend' then
   target:=(payload->>'id')::uuid;
   delete from mwm_private.friends where (user_id=uid and friend_id=target) or (user_id=target and friend_id=uid);
 elsif action='cheer' then
   entry:=(payload->>'id')::uuid;
   if not exists(select 1 from mwm_private.drinks d join mwm_private.friends f on f.friend_id=d.user_id where f.user_id=uid and d.id=entry) then raise exception 'Diesen Eintrag kannst du nicht sehen.' using errcode='42501';end if;
   insert into mwm_private.cheers(drink_id,sender_id) values(entry,uid) on conflict do nothing;
 else raise exception 'Unbekannte Aktion.';end if;
 return mwm_private.state();
end $$;
create function mwm_private.invitation(code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); person mwm_private.profiles;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 if coalesce(code,'') !~ '^[0-9a-fA-F]{24}$' then raise exception 'Ungültige Einladung.';end if;
 select * into person from mwm_private.profiles where invite=lower(code);
 if person.id is null then raise exception 'Diese Einladung ist nicht mehr gültig.';end if;
 if person.id=uid then raise exception 'Das ist dein eigener QR-Code. Lass ihn von deinem Freund scannen.';end if;
 return jsonb_build_object('name',person.name,'alreadyConnected',exists(select 1 from mwm_private.friends where user_id=uid and friend_id=person.id));
end $$;
revoke all on all functions in schema mwm_private from public,anon;
grant execute on all functions in schema mwm_private to authenticated;
create function public.mwm_state() returns jsonb language sql security invoker set search_path='' as $$ select mwm_private.state(); $$;
create function public.mwm_action(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$ select mwm_private.action(payload); $$;
create function public.mwm_invitation(code text) returns jsonb language sql security invoker set search_path='' as $$ select mwm_private.invitation(code); $$;
revoke all on function public.mwm_state(),public.mwm_action(jsonb),public.mwm_invitation(text) from public,anon;
grant execute on function public.mwm_state(),public.mwm_action(jsonb),public.mwm_invitation(text) to authenticated;

-- Monster With Me: opt-in Web Push, isolated from other apps.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
alter table mwm_private.drinks drop constraint drinks_kind_check;
alter table mwm_private.drinks add constraint drinks_kind_check check(kind in ('Monster Energy','Monster Ultra White','Monster Mango Loco','Monster Pipeline Punch','Monster Zero Sugar','Monster Lando Norris','Monster Lewis Hamilton'));
create table mwm_private.push_config(singleton boolean primary key default true check(singleton),public_key text not null,private_secret uuid not null,dispatch_secret uuid not null,enabled boolean not null default false);
create table mwm_private.push_devices(id uuid primary key default gen_random_uuid(),user_id uuid not null references mwm_private.profiles(id) on delete cascade,endpoint text not null unique,p256dh text not null,auth_key text not null,created_at timestamptz not null default now(),last_test_at timestamptz);
create index mwm_push_devices_user on mwm_private.push_devices(user_id);
create table mwm_private.push_jobs(id uuid primary key default gen_random_uuid(),device_id uuid not null references mwm_private.push_devices(id) on delete cascade,drink_id uuid references mwm_private.drinks(id) on delete cascade,created_at timestamptz not null default now(),attempts integer not null default 0,next_attempt timestamptz not null default now(),lease uuid,unique(device_id,drink_id));
create index mwm_push_jobs_due on mwm_private.push_jobs(next_attempt);
alter table mwm_private.push_config enable row level security;
alter table mwm_private.push_devices enable row level security;
alter table mwm_private.push_jobs enable row level security;
revoke all on mwm_private.push_config,mwm_private.push_devices,mwm_private.push_jobs from public,anon,authenticated;
create function mwm_private.push_endpoint_valid(endpoint text) returns boolean language sql immutable set search_path='' as $$
 select length(endpoint) between 30 and 2048 and endpoint ~ '^https://([a-zA-Z0-9-]+\.)*(push\.apple\.com|push\.services\.mozilla\.com|notify\.windows\.com)/[^[:space:]]+$' or length(endpoint) between 30 and 2048 and endpoint ~ '^https://fcm\.googleapis\.com/[^[:space:]]+$';
$$;
create function mwm_private.push_settings(endpoint text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 return jsonb_build_object('publicKey',(select public_key from mwm_private.push_config where enabled),'enabled',exists(select 1 from mwm_private.push_devices d where d.user_id=uid and d.endpoint=push_settings.endpoint));
end $$;
create function mwm_private.push_subscribe(subscription jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); ep text:=subscription->>'endpoint'; pk text:=subscription#>>'{keys,p256dh}'; ak text:=subscription#>>'{keys,auth}';begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 if not exists(select 1 from mwm_private.push_config where enabled) then raise exception 'Push-Mitteilungen sind noch nicht bereit.';end if;
 if not coalesce(mwm_private.push_endpoint_valid(ep),false) or coalesce(pk,'') !~ '^[A-Za-z0-9_-]{87}={0,1}$' or coalesce(ak,'') !~ '^[A-Za-z0-9_-]{22}={0,2}$' then raise exception 'Ungültige Push-Anmeldung.';end if;
 insert into mwm_private.profiles(id) values(uid) on conflict do nothing;
 if exists(select 1 from mwm_private.push_devices where endpoint=ep and user_id<>uid) then raise exception 'Bitte Push auf diesem Gerät neu aktivieren.';end if;
 if (select count(*) from mwm_private.push_devices where user_id=uid)>=10 and not exists(select 1 from mwm_private.push_devices where endpoint=ep and user_id=uid) then raise exception 'Zu viele angemeldete Geräte.';end if;
 insert into mwm_private.push_devices(user_id,endpoint,p256dh,auth_key) values(uid,ep,pk,ak) on conflict(endpoint) do update set p256dh=excluded.p256dh,auth_key=excluded.auth_key where push_devices.user_id=uid;
 return jsonb_build_object('enabled',true);
end $$;
create function mwm_private.push_unsubscribe(endpoint text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 delete from mwm_private.push_devices d where d.user_id=auth.uid() and d.endpoint=push_unsubscribe.endpoint;
end $$;
create function mwm_private.push_wake() returns void language plpgsql security definer set search_path='' as $$
declare token text;begin
 delete from mwm_private.push_jobs where created_at<=now()-interval '15 minutes';
 if not exists(select 1 from mwm_private.push_config where enabled) or not exists(select 1 from mwm_private.push_jobs where next_attempt<=now() and created_at>now()-interval '15 minutes' and attempts<5) then return;end if;
 select s.decrypted_secret into token from vault.decrypted_secrets s join mwm_private.push_config c on c.dispatch_secret=s.id where c.enabled;
 perform net.http_post(url:='https://tpuufwcywwhrggfptzpi.supabase.co/functions/v1/mwm-push',headers:=jsonb_build_object('Content-Type','application/json','x-mwm-dispatch-token',token),body:='{}'::jsonb,timeout_milliseconds:=30000);
end $$;
create function mwm_private.push_enqueue() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from mwm_private.push_config where enabled) then
 insert into mwm_private.push_jobs(device_id,drink_id) select s.id,new.id from mwm_private.friends f join mwm_private.push_devices s on s.user_id=f.friend_id where f.user_id=new.user_id on conflict do nothing;
 -- Notification infrastructure must never prevent saving a drink.
 begin perform mwm_private.push_wake();exception when others then null;end;
 end if;return new;
end $$;
create trigger mwm_drink_push after insert on mwm_private.drinks for each row execute function mwm_private.push_enqueue();
create function mwm_private.push_test(endpoint text) returns void language plpgsql security definer set search_path='' as $$
declare dev uuid;begin
 if auth.uid() is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 select id into dev from mwm_private.push_devices d where d.user_id=auth.uid() and d.endpoint=push_test.endpoint;
 if dev is null then raise exception 'Aktiviere zuerst Push-Mitteilungen.';end if;
 if exists(select 1 from mwm_private.push_devices where id=dev and last_test_at>now()-interval '1 minute') then raise exception 'Bitte eine Minute warten.';end if;
 update mwm_private.push_devices set last_test_at=now() where id=dev;
 insert into mwm_private.push_jobs(device_id) values(dev);
 perform mwm_private.push_wake();
end $$;
create function mwm_private.push_claim(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare config mwm_private.push_config;expected text; private_key text; jobs jsonb;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Nicht erlaubt.' using errcode='42501';end if;
 select * into config from mwm_private.push_config where enabled;
 select decrypted_secret into expected from vault.decrypted_secrets where id=config.dispatch_secret;
 if expected is null or token is null or token<>expected then raise exception 'Nicht erlaubt.' using errcode='42501';end if;
 select decrypted_secret into private_key from vault.decrypted_secrets where id=config.private_secret;
 delete from mwm_private.push_jobs j where j.created_at<=now()-interval '15 minutes' or j.attempts>=5 or (j.drink_id is not null and not exists(select 1 from mwm_private.drinks d join mwm_private.push_devices s on s.id=j.device_id join mwm_private.friends f on f.user_id=d.user_id and f.friend_id=s.user_id where d.id=j.drink_id));
 with due as (select id from mwm_private.push_jobs where next_attempt<=now() order by created_at limit 40 for update skip locked), claimed as (update mwm_private.push_jobs j set lease=gen_random_uuid(),attempts=j.attempts+1,next_attempt=now()+interval '2 minutes' from due where due.id=j.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'lease',j.lease,'endpoint',s.endpoint,'keys',jsonb_build_object('p256dh',s.p256dh,'auth',s.auth_key),'payload',case when j.drink_id is null then jsonb_build_object('title','Monster With Me ⚡','body','Push-Mitteilungen sind aktiviert.','tag','mwm-test') else jsonb_build_object('title','Monster With Me ⚡','body',p.name||' hat gerade '||d.amount||' ml '||d.kind||' getrunken.','tag','mwm-'||d.id,'drinkId',d.id) end)), '[]'::jsonb) into jobs from claimed j join mwm_private.push_devices s on s.id=j.device_id left join mwm_private.drinks d on d.id=j.drink_id left join mwm_private.profiles p on p.id=d.user_id;
 return jsonb_build_object('vapid',jsonb_build_object('subject','https://basti92bot.github.io/monster-with-me-/','publicKey',config.public_key,'privateKey',private_key),'jobs',jobs);
end $$;
create function mwm_private.push_finish(job_id uuid,claim uuid,status integer) returns void language plpgsql security definer set search_path='' as $$
declare dev uuid;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Nicht erlaubt.' using errcode='42501';end if;
 select device_id into dev from mwm_private.push_jobs where id=job_id and lease=claim;
 if dev is null then return;end if;
 if status in(404,410) then delete from mwm_private.push_devices where id=dev;
 elsif status between 200 and 299 or status between 400 and 499 and status<>429 then delete from mwm_private.push_jobs where id=job_id and lease=claim;
 else update mwm_private.push_jobs set next_attempt=now()+interval '1 minute',lease=null where id=job_id and lease=claim;end if;
end $$;
revoke all on function mwm_private.push_endpoint_valid(text),mwm_private.push_settings(text),mwm_private.push_subscribe(jsonb),mwm_private.push_unsubscribe(text),mwm_private.push_test(text),mwm_private.push_wake(),mwm_private.push_enqueue(),mwm_private.push_claim(text),mwm_private.push_finish(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function mwm_private.push_settings(text),mwm_private.push_subscribe(jsonb),mwm_private.push_unsubscribe(text),mwm_private.push_test(text) to authenticated;
grant usage on schema mwm_private to service_role;
grant execute on function mwm_private.push_claim(text),mwm_private.push_finish(uuid,uuid,integer) to service_role;
create function public.mwm_push_settings(endpoint text default '') returns jsonb language sql security invoker set search_path='' as $$select mwm_private.push_settings(endpoint);$$;
create function public.mwm_push_subscribe(subscription jsonb) returns jsonb language sql security invoker set search_path='' as $$select mwm_private.push_subscribe(subscription);$$;
create function public.mwm_push_unsubscribe(endpoint text) returns void language sql security invoker set search_path='' as $$select mwm_private.push_unsubscribe(endpoint);$$;
create function public.mwm_push_test(endpoint text) returns void language sql security invoker set search_path='' as $$select mwm_private.push_test(endpoint);$$;
create function public.mwm_push_claim(token text) returns jsonb language sql security invoker set search_path='' as $$select mwm_private.push_claim(token);$$;
create function public.mwm_push_finish(job_id uuid,claim uuid,status integer) returns void language sql security invoker set search_path='' as $$select mwm_private.push_finish(job_id,claim,status);$$;
revoke all on function public.mwm_push_settings(text),public.mwm_push_subscribe(jsonb),public.mwm_push_unsubscribe(text),public.mwm_push_test(text),public.mwm_push_claim(text),public.mwm_push_finish(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.mwm_push_settings(text),public.mwm_push_subscribe(jsonb),public.mwm_push_unsubscribe(text),public.mwm_push_test(text) to authenticated;
grant execute on function public.mwm_push_claim(text),public.mwm_push_finish(uuid,uuid,integer) to service_role;
select cron.schedule('mwm-push-retry','* * * * *',$cron$select mwm_private.push_wake();$cron$);

create or replace function mwm_private.action(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); target uuid; entry uuid; action text:=payload->>'action'; amount integer; new_goal integer; new_name text;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into mwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 if action='drink' then
   if coalesce(payload->>'kind','') not in ('Monster Energy','Monster Ultra White','Monster Mango Loco','Monster Pipeline Punch','Monster Zero Sugar','Monster Lando Norris','Monster Lewis Hamilton') or coalesce(payload->>'amount','') !~ '^[0-9]{1,4}$' then raise exception 'Ungültiges Getränk oder Menge.';end if;
   amount:=(payload->>'amount')::integer;entry:=(payload->>'id')::uuid;
   if amount<1 or amount>3000 or entry is null then raise exception 'Bitte 1 bis 3.000 ml wählen.';end if;
   if exists(select 1 from mwm_private.drinks where id=entry and user_id<>uid) then raise exception 'Eintrag gehört nicht zu dir.' using errcode='42501';end if;
   insert into mwm_private.drinks(id,user_id,kind,amount) values(entry,uid,payload->>'kind',amount) on conflict(id) do nothing;
 elsif action='delete' then
   delete from mwm_private.drinks where id=(payload->>'id')::uuid and user_id=uid;
 elsif action='profile' then
   new_name:=trim(payload->>'name');
   if coalesce(payload->>'goal','') !~ '^[0-9]{3,4}$' or new_name is null or char_length(new_name) not between 1 and 30 then raise exception 'Bitte Name und Tageslimit prüfen.';end if;
   new_goal:=(payload->>'goal')::integer;if new_goal not between 250 and 3000 then raise exception 'Tageslimit: 250 bis 3.000 ml.';end if;
   update mwm_private.profiles set name=new_name,goal=new_goal where id=uid;
 elsif action='friend' then
   select id into target from mwm_private.profiles where invite=lower(trim(payload->>'code'));
   if target is null or target=uid then raise exception 'Kein gültiger Freundescode.';end if;
   insert into mwm_private.friends(user_id,friend_id) values(uid,target),(target,uid) on conflict do nothing;
 elsif action='unfriend' then
   target:=(payload->>'id')::uuid;
   delete from mwm_private.friends where (user_id=uid and friend_id=target) or (user_id=target and friend_id=uid);
 elsif action='cheer' then
   entry:=(payload->>'id')::uuid;
   if not exists(select 1 from mwm_private.drinks d join mwm_private.friends f on f.friend_id=d.user_id where f.user_id=uid and d.id=entry) then raise exception 'Diesen Eintrag kannst du nicht sehen.' using errcode='42501';end if;
   insert into mwm_private.cheers(drink_id,sender_id) values(entry,uid) on conflict do nothing;
 else raise exception 'Unbekannte Aktion.';end if;
 return mwm_private.state();
end $$;

create or replace function mwm_private.notification(entry_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); notice jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 select jsonb_build_object('id',d.id,'name',p.name,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000)) into notice
 from mwm_private.drinks d join mwm_private.profiles p on p.id=d.user_id
 where d.id=entry_id and (d.user_id=uid or exists(select 1 from mwm_private.friends f where f.user_id=uid and f.friend_id=d.user_id));
 if notice is null then raise exception 'Diesen Eintrag kannst du nicht sehen.' using errcode='42501';end if;
 return notice;
end $$;
revoke all on function mwm_private.notification(uuid) from public,anon,authenticated;
grant execute on function mwm_private.notification(uuid) to authenticated;
create or replace function public.mwm_notification(entry_id uuid) returns jsonb language sql security invoker set search_path='' as $$select mwm_private.notification(entry_id);$$;
revoke all on function public.mwm_notification(uuid) from public,anon,authenticated;
grant execute on function public.mwm_notification(uuid) to authenticated;


-- Reuse the project's existing VAPID identity; keep subscriptions and dispatcher authorization separate.
do $$
declare dispatcher uuid;begin
 select vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'mwm_dispatch_token','Monster With Me push dispatcher') into dispatcher;
 insert into mwm_private.push_config(singleton,public_key,private_secret,dispatch_secret,enabled) select true,public_key,private_secret,dispatcher,true from wwm_private.push_config where enabled;
 if not found then raise exception 'Existing push identity missing';end if;
end $$;
