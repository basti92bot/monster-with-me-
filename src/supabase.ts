import { createClient } from '@supabase/supabase-js';
export const supabase=createClient('https://tpuufwcywwhrggfptzpi.supabase.co','sb_publishable_79GQl0jJBeQ8FKBj2TfnRw_JDyZf1oS',{auth:{storageKey:'monster-with-me-auth',persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}});
