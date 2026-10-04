import {useEffect,useState} from 'react';
import {GlassWater} from 'lucide-react';
import {supabase} from './supabase';
import {Dialog,DialogContent,DialogTitle,DialogDescription} from '@/components/ui/dialog';
type Notice={id:string;name:string;kind:string;amount:number;created_at:number};
export default function DrinkPopup({entryId,onClose}:{entryId:string;onClose:()=>void}){
 const [notice,setNotice]=useState<Notice|null>(null),[error,setError]=useState('');
 useEffect(()=>{if(!entryId)return;let active=true;setNotice(null);setError('');void Promise.resolve(supabase.rpc('mwm_notification',{entry_id:entryId})).then(({data,error})=>{if(!active)return;if(error||!data){setError('Dieses Getränk ist nicht mehr verfügbar oder ihr seid nicht mehr verbunden.');return;}setNotice(data as Notice);}).catch(()=>{if(active)setError('Die Mitteilung konnte nicht geladen werden. Bitte öffne sie erneut.');});return()=>{active=false;};},[entryId]);
 return <Dialog open={!!entryId} onOpenChange={open=>{if(!open)onClose();}}><DialogContent className="app-dialog drink-popup"><DialogTitle>{notice?`${notice.name} trinkt!`:'Getränk-Mitteilung'}</DialogTitle><DialogDescription>{notice?'Ein neuer Schluck aus deiner Runde.':'Getränk und Menge aus deiner Runde.'}</DialogDescription>{error?<p role="alert">{error}</p>:notice?<><div className="popup-drink"><GlassWater size={32}/><div><strong>{notice.kind}</strong><p>{new Intl.NumberFormat('de-DE').format(notice.amount)} ml · {new Intl.DateTimeFormat('de-DE',{hour:'2-digit',minute:'2-digit',timeZone:'Europe/Berlin'}).format(notice.created_at)} Uhr</p></div></div></>:<p role="status">Mitteilung wird geladen…</p>}<button className="button primary full" onClick={onClose}>Schließen</button></DialogContent></Dialog>;
}
