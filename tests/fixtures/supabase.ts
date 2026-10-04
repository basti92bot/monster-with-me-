export const state={profile:{name:'Testperson',goal:500,invite:'1234567890abcdef12345678'},today:'2026-10-04',entries:[],friends:[],week:Array.from({length:7},(_,i)=>({day:`2026-10-0${i+1}`,total:0}))};
export const calls:any[]=[];
export const notice={id:'11111111-1111-4111-8111-111111111111',name:'Testfreund',kind:'Monster Energy',amount:500,created_at:Date.now()};
export const noticeResult:{data:typeof notice|null,error:null|{code:string}}={data:notice,error:null};
export const authResult:{error:null|{code:string},data:{session:null}}={error:null,data:{session:null}};
export const supabase={rpc:async(name:string,args:any={})=>{calls.push({name,args});if(name==='mwm_notification')return noticeResult;if(name==='mwm_push_settings')return {data:{publicKey:'B'.repeat(87),enabled:false},error:null};if(name==='mwm_push_subscribe'||name==='mwm_push_test'||name==='mwm_push_unsubscribe')return {data:{enabled:true},error:null};return {data:state,error:null};},auth:{signOut:async()=>({error:null}),signUp:async(args:any)=>{calls.push({name:'signUp',args});return authResult;},signInWithPassword:async(args:any)=>{calls.push({name:'signInWithPassword',args});return authResult;}}};
