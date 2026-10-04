begin;
do $$
declare person uuid:=gen_random_uuid();water_drink uuid:=gen_random_uuid();monster_drink uuid:=gen_random_uuid();data jsonb;
begin
 insert into auth.users(id,aud,role,email,raw_user_meta_data,raw_app_meta_data,created_at,updated_at) values(person,'authenticated','authenticated','mwm-isolation-'||person||'@example.invalid','{}','{}',now(),now());
 perform set_config('request.jwt.claim.sub',person::text,true);
 perform public.wwm_action(jsonb_build_object('action','drink','id',water_drink,'kind','Monster Energy','amount',500));
 data:=public.mwm_state();if jsonb_array_length(data->'entries')<>0 or jsonb_array_length(data->'friends')<>0 then raise exception 'Water data leaked into Monster';end if;
 perform public.mwm_action(jsonb_build_object('action','drink','id',monster_drink,'kind','Monster Ultra White','amount',500));
 if public.mwm_state()#>>'{entries,0,id}'<>monster_drink::text or public.wwm_state()#>>'{entries,0,id}'<>water_drink::text then raise exception 'Apps share drink state';end if;
 begin perform public.mwm_notification(water_drink);raise exception 'Water entry accessible from Monster';exception when insufficient_privilege then null;end;
 begin perform public.wwm_notification(monster_drink);raise exception 'Monster entry accessible from Water';exception when insufficient_privilege then null;end;
 begin perform public.mwm_action(jsonb_build_object('action','drink','id',gen_random_uuid(),'kind','Kaffee','amount',250));raise exception 'Non-Monster drink accepted';exception when others then if sqlerrm='Non-Monster drink accepted' then raise;end if;end;
 if has_function_privilege('anon','public.mwm_notification(uuid)','execute') then raise exception 'Anonymous popup exposed';end if;
end $$;
select 'Monster isolation passed: own data, authorized popups, allowed flavors and shared login identity.' as result;
rollback;
