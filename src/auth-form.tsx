import {useState} from 'react';
import {supabase} from './supabase';

function authError(code?:string){
 if(code==='email_address_not_authorized')return 'Der E-Mail-Versand lässt diese Adresse derzeit nicht zu. Der Versanddienst muss dafür eingerichtet werden.';
 if(code==='over_email_send_rate_limit'||code==='over_request_rate_limit')return 'Zu viele Versuche. Bitte warte einige Minuten und versuche es erneut.';
 if(code==='weak_password')return 'Wähle ein stärkeres Passwort mit mindestens 8 Zeichen.';
 if(code==='user_already_exists')return 'Für diese E-Mail besteht bereits ein Konto. Wähle „Anmelden“.';
 if(code==='email_not_confirmed')return 'Bitte bestätige zuerst deine E-Mail und melde dich danach an.';
 if(code==='signup_disabled')return 'Die Registrierung ist momentan deaktiviert.';
 return 'Der Server konnte die Anfrage nicht abschließen. Bitte versuche es erneut.';
}

export default function AuthForm(){
 const [signup,setSignup]=useState(false),[email,setEmail]=useState(''),[password,setPassword]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 async function submit(e:React.FormEvent<HTMLFormElement>){
  e.preventDefault();if(busy)return;
  const address=email.trim();
  if(!address||!e.currentTarget.elements.namedItem('email')||(e.currentTarget.elements.namedItem('email') as HTMLInputElement).validity.typeMismatch){setMessage('Bitte gib eine gültige E-Mail-Adresse ein.');return;}
  if(!password){setMessage('Bitte gib dein Passwort ein.');return;}
  if(signup&&password.length<8){setMessage('Dein Passwort braucht mindestens 8 Zeichen.');return;}
  setBusy(true);setMessage('');let timeout:ReturnType<typeof setTimeout>|undefined;
  try{
   const request=signup?supabase.auth.signUp({email:address,password}):supabase.auth.signInWithPassword({email:address,password});
   const result=await Promise.race([request,new Promise<never>((_,reject)=>{timeout=setTimeout(()=>reject(new Error('timeout')),20000);})]);
   if(result.error){setMessage(result.error.code==='invalid_credentials'?'Anmeldung fehlgeschlagen. Prüfe E-Mail und Passwort.':authError(result.error.code));return;}
   if(signup&&!result.data.session)setMessage('Bei einer neuen Adresse: Prüfe dein Postfach und den Spam-Ordner und bestätige deine E-Mail. Hast du schon ein RepPilot-Konto, wähle „Anmelden“ und nutze dessen Passwort. Dafür kommt keine neue Bestätigungsmail.');
  }catch{setMessage('Die Verbindung antwortet gerade nicht. Prüfe dein Netz und versuche es erneut.');}
  finally{clearTimeout(timeout);setBusy(false);}
 }
 return <><p className="subtext">{signup?'Erstelle dein Konto und verbinde dich mit deinen Freunden.':'Deine Sorte. Deine Crew. Dein Monster-Moment.'}</p>
  <div className="auth-tabs" aria-label="Anmeldung oder Registrierung">{[false,true].map(mode=><button key={String(mode)} type="button" className={`button ${signup===mode?'primary':'secondary'}`} aria-pressed={signup===mode} disabled={busy} onClick={()=>{setSignup(mode);setMessage('');}}>{mode?'Konto erstellen':'Anmelden'}</button>)}</div>
  <form noValidate onSubmit={submit}>
   <label className="form-label">E-Mail<input name="email" type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="email" required/></label>
   <label className="form-label">Passwort<input name="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} autoComplete={signup?'new-password':'current-password'} aria-describedby={signup?'password-help':undefined} required/>{signup&&<small id="password-help" className="password-help">Mindestens 8 Zeichen.</small>}</label>
   <button type="submit" className="button primary full" disabled={busy}>{busy?'Einen Moment…':signup?'Jetzt Konto erstellen':'Anmelden'}</button>
   <p className="auth-message" role="status" aria-live="polite">{message}</p>
  </form><p className="form-help auth-note">Deine Anmeldung aus RepPilot oder Water With Me funktioniert auch hier. Deine E-Mail sehen deine Freunde nicht.</p></>;
}
