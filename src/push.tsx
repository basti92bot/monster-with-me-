import {useEffect,useState} from 'react';
import {Bell,BellOff} from 'lucide-react';
import {supabase} from './supabase';
const ownerKey='mwm-push-owner';
const supported=()=>window.isSecureContext&&'serviceWorker' in navigator&&'PushManager' in window&&'Notification' in window;
async function registration(){
 if(!supported())throw new Error('Push ist in diesem Browser nicht verfügbar.');
 await navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'});
 return navigator.serviceWorker.ready;
}
export async function ensurePushAccount(userId:string){
 if(!supported())return;
 const reg=await registration(),sub=await reg.pushManager.getSubscription();
 if(sub&&localStorage.getItem(ownerKey)!==userId){await sub.unsubscribe();localStorage.removeItem(ownerKey);}
}
export async function disablePush(){
 if(!supported())return;
 const reg=await registration(),sub=await reg.pushManager.getSubscription();
 if(!sub){localStorage.removeItem(ownerKey);return;}
 let error:Error|null=null;
 try{const result=await supabase.rpc('mwm_push_unsubscribe',{endpoint:sub.endpoint});if(result.error)error=new Error('Das Gerät konnte auf dem Server nicht abgemeldet werden.');}
 finally{await sub.unsubscribe();localStorage.removeItem(ownerKey);}
 if(error)throw error;
}
function keyBytes(value:string){return Uint8Array.from(atob(value.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-value.length%4)%4)),c=>c.charCodeAt(0));}
export default function PushSettings({userId}:{userId:string}){
 const [enabled,setEnabled]=useState(false),[key,setKey]=useState(''),[busy,setBusy]=useState(true),[message,setMessage]=useState('');
 const available=supported();
 useEffect(()=>{let active=true;void(async()=>{
  if(!available){if(active)setBusy(false);return;}
  try{await ensurePushAccount(userId);const reg=await registration(),sub=await reg.pushManager.getSubscription();const {data,error}=await supabase.rpc('mwm_push_settings',{endpoint:sub?.endpoint||''});if(error)throw new Error('Push-Einstellungen konnten nicht geladen werden. Öffne das Profil erneut.');if(active){setKey(data.publicKey||'');setEnabled(!!data.enabled&&!!sub&&Notification.permission==='granted');}}
  catch(e){if(active)setMessage((e as Error).message);}finally{if(active)setBusy(false);}
 })();return()=>{active=false;};},[userId,available]);
 const toggle=async()=>{
  // Request permission directly in the tap handler, before any network await (iOS).
  const permission=!enabled?Notification.requestPermission():Promise.resolve(Notification.permission);
  setBusy(true);setMessage('');
  try{
   if(enabled){await disablePush();setEnabled(false);setMessage('Mitteilungen auf diesem Gerät deaktiviert.');return;}
   if(await permission!=='granted'){setMessage('Mitteilungen wurden nicht erlaubt. Du kannst das in den Geräte-Einstellungen ändern.');return;}
   const reg=await registration();let sub=await reg.pushManager.getSubscription();
   if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:keyBytes(key)});
   const {error}=await supabase.rpc('mwm_push_subscribe',{subscription:sub.toJSON()});
   if(error){await sub.unsubscribe();throw new Error('Push konnte nicht aktiviert werden. Bitte erneut versuchen.');}
   localStorage.setItem(ownerKey,userId);setEnabled(true);setMessage('Aktiviert. Du bekommst eine Mitteilung, wenn ein Freund ein Getränk einträgt.');
  }catch(e){setMessage((e as Error).message);}finally{setBusy(false);}
 };
 const test=async()=>{setBusy(true);setMessage('');try{const sub=await(await registration()).pushManager.getSubscription();if(!sub)throw new Error('Aktiviere Push erneut.');const {error}=await supabase.rpc('mwm_push_test',{endpoint:sub.endpoint});if(error)throw new Error(error.message.includes('Minute')?'Bitte eine Minute warten.':'Test-Mitteilung konnte nicht gesendet werden.');setMessage('Test-Mitteilung angefordert. Sie sollte gleich auf diesem Gerät erscheinen.');}catch(e){setMessage((e as Error).message);}finally{setBusy(false);}};
 return <section className="push-settings" aria-label="Push-Mitteilungen"><div className="push-heading"><Bell size={20}/><strong>Push-Mitteilungen</strong><span>{enabled?'An':'Aus'}</span></div><p>Erfahre auch bei geschlossener App, wenn deine Freunde etwas trinken.</p>{available?<><button type="button" className={'button full '+(enabled?'secondary':'primary')} disabled={busy||!key} onClick={()=>void toggle()}>{enabled?<BellOff size={17}/>:<Bell size={17}/>} {busy?'Lädt…':enabled?'Auf diesem Gerät ausschalten':'Auf diesem Gerät aktivieren'}</button>{enabled&&<button type="button" className="button secondary full push-test" disabled={busy} onClick={()=>void test()}>Test-Mitteilung senden</button>}</>:<p className="push-help">Push ist hier nicht verfügbar. Auf dem iPhone: in Safari zum Home-Bildschirm hinzufügen und die App über ihr Icon öffnen.</p>}<p className="push-help">iPhone: Safari → Teilen → Zum Home-Bildschirm. Danach hier aktivieren und „Erlauben“ wählen. Jeder Freund aktiviert dies auf seinem eigenen Gerät.</p>{message&&<p className="push-message" role="status">{message}</p>}</section>;
}
