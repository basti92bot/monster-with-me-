import React,{useEffect,useState} from 'react';
import { createRoot } from 'react-dom/client';
import type {Session} from '@supabase/supabase-js';
import {EnergyMark} from './energy-brand';
import {supabase} from './supabase';
import MonsterApp from './monster-app';
import AuthForm from './auth-form';
import './globals.css';
function App(){
 const [session,setSession]=useState<Session|null>(null),[ready,setReady]=useState(false);
 useEffect(()=>{void supabase.auth.getSession().then(({data})=>{setSession(data.session);setReady(true);});const{data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{setSession(next);setReady(true);});return()=>subscription.unsubscribe();},[]);
 if(!ready)return <main className="auth-wrap"><p>Monster With Me lädt…</p></main>;
 if(session)return <MonsterApp userId={session.user.id} initialInvite={new URL(window.location.href).searchParams.get('invite')||''}/>;
 return <main className="auth-wrap"><div className="auth-card"><div className="auth-brand"><EnergyMark className="brand-claw"/><h1>Monster With Me</h1></div><AuthForm/></div></main>;
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>);
if('serviceWorker' in navigator){
 let notified=false;
 const hadController=!!navigator.serviceWorker.controller;
 navigator.serviceWorker.addEventListener('controllerchange',()=>{
  if(!hadController||notified)return;
  notified=true;
  const notice=document.createElement('div');notice.className='app-update';notice.setAttribute('role','status');notice.append('Update verfügbar.');
  const button=document.createElement('button');button.textContent='Neu laden';button.onclick=()=>window.location.reload();notice.append(button);document.body.append(notice);
 });
 window.addEventListener('load',()=>{void navigator.serviceWorker.register('./sw.js',{updateViaCache:'none'}).then(reg=>{
  const check=()=>{if(document.visibilityState==='visible')void reg.update().catch(()=>{});};
  document.addEventListener('visibilitychange',check);window.addEventListener('online',check);check();
 }).catch(()=>{});});
}
