import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import webpush from 'npm:web-push@3.6.7';
import {dispatchJobs} from './dispatch.mjs';
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(async req=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const token=req.headers.get('x-mwm-dispatch-token');
 if(!token||!/^[a-f0-9]{64}$/.test(token))return new Response('Unauthorized',{status:401});
 const {data,error}=await db.rpc('mwm_push_claim',{token});
 if(error)return new Response('Unauthorized',{status:401});
 try {
 const result=await dispatchJobs(data,{requestDetails:webpush.generateRequestDetails.bind(webpush),send:fetch,finish:async(id:string,lease:string,status:number)=>{const {error}=await db.rpc('mwm_push_finish',{job_id:id,claim:lease,status});if(error)throw new Error('Queue acknowledgement failed');}});
 return Response.json(result);
 }catch{return new Response('Delivery temporarily unavailable',{status:503});}
});
