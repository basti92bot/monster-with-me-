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
if('serviceWorker' in navigator)window.addEventListener('load',()=>{void navigator.serviceWorker.register('./sw.js',{updateViaCache:'none'}).catch(()=>{});});
