begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); entry uuid:=gen_random_uuid(); invitation text; result jsonb;
begin
 if has_function_privilege('anon','public.mwm_state()','execute') or has_table_privilege('authenticated','mwm_private.drinks','select') then raise exception 'Unexpected client privileges';end if;
 insert into auth.users(id,aud,role,email,raw_user_meta_data,raw_app_meta_data,created_at,updated_at) values
 (a,'authenticated','authenticated','mwm-test-a-'||a::text||'@example.invalid','{}','{}',now(),now()),
 (b,'authenticated','authenticated','mwm-test-b-'||b::text||'@example.invalid','{}','{}',now(),now()),
 (c,'authenticated','authenticated','mwm-test-c-'||c::text||'@example.invalid','{}','{}',now(),now());
 perform set_config('request.jwt.claim.sub',a::text,true);
 result:=public.mwm_action(jsonb_build_object('action','drink','id',entry,'kind','Monster Energy','amount',500));
 if jsonb_array_length(result->'entries')<>1 or (result#>>'{week,6,total}')::integer<>500 then raise exception 'Entry or daily total failed';end if;
 invitation:=result#>>'{profile,invite}';
 perform public.mwm_action(jsonb_build_object('action','profile','name','Test A','goal',2000));
 perform set_config('request.jwt.claim.sub',b::text,true);
 result:=public.mwm_state();if jsonb_array_length(result->'entries')<>0 or jsonb_array_length(result->'friends')<>0 then raise exception 'Data leaked to unrelated user';end if;
 result:=public.mwm_invitation(invitation);if result->>'name'<>'Test A' or (result->>'alreadyConnected')::boolean then raise exception 'Invitation preview failed';end if;
 result:=public.mwm_action(jsonb_build_object('action','friend','code',invitation));
 if jsonb_array_length(result->'friends')<>1 or (result#>>'{friends,0,total}')::integer<>500 then raise exception 'Friend feed failed';end if;
 perform public.mwm_action(jsonb_build_object('action','delete','id',entry));
 if not exists(select 1 from mwm_private.drinks where id=entry) then raise exception 'Someone deleted another user entry';end if;
 perform public.mwm_action(jsonb_build_object('action','cheer','id',entry));
 perform public.mwm_action(jsonb_build_object('action','cheer','id',entry));
 if (select count(*) from mwm_private.cheers where drink_id=entry)<>1 then raise exception 'Duplicate reaction';end if;
 perform set_config('request.jwt.claim.sub',c::text,true);perform public.mwm_state();
 begin
  perform public.mwm_action(jsonb_build_object('action','cheer','id',entry));raise exception 'Unauthorized reaction accepted';
 exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 result:=public.mwm_state();if jsonb_array_length(result->'friends')<>1 then raise exception 'Reciprocal friendship failed';end if;
 perform public.mwm_action(jsonb_build_object('action','delete','id',entry));
 if exists(select 1 from mwm_private.cheers where drink_id=entry) then raise exception 'Reaction cascade failed';end if;
 perform public.mwm_action(jsonb_build_object('action','unfriend','id',b));
 if exists(select 1 from mwm_private.friends where user_id in(a,b)) then raise exception 'Unfriend failed';end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.mwm_state();raise exception 'Unauthenticated call accepted';exception when insufficient_privilege then null;end;
end $$;
select 'Monster With Me tests passed: isolated state, profile settings, invitation preview, reciprocal friends, ownership, reactions, unfriend, unauthenticated rejection.' as result;
rollback;
