export function allowedEndpoint(endpoint) {
 try {const u=new URL(endpoint);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&u.pathname.length>1&&(u.hostname==='fcm.googleapis.com'||['push.apple.com','push.services.mozilla.com','notify.windows.com'].some(h=>u.hostname===h||u.hostname.endsWith('.'+h)));}catch{return false;}
}
export async function dispatchJobs(data,{requestDetails,send,finish}) {
 let sent=0,failed=0;
 for(let i=0;i<data.jobs.length;i+=8)await Promise.all(data.jobs.slice(i,i+8).map(async job=>{
  let status=400;
  if(allowedEndpoint(job.endpoint))try {
   const details=requestDetails({endpoint:job.endpoint,keys:job.keys},JSON.stringify(job.payload),{vapidDetails:data.vapid,TTL:900,urgency:'normal',contentEncoding:'aes128gcm'});
   const response=await send(details.endpoint,{method:'POST',headers:details.headers,body:new Uint8Array(details.body),redirect:'error',signal:AbortSignal.timeout(12000)});
   status=response.status;
  }catch{status=503;}
  await finish(job.id,job.lease,status);if(status>=200&&status<300)sent++;else failed++;
 }));
 return {sent,failed};
}
