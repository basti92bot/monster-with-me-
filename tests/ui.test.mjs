import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import React,{act} from 'react';
const dom=new JSDOM('<html><body><div id="root"></div></body></html>',{url:'https://basti92bot.github.io/monster-with-me-/'});
const win=dom.window;
for(const [name,value] of Object.entries({window:win,document:win.document,navigator:win.navigator,localStorage:win.localStorage,HTMLElement:win.HTMLElement,Element:win.Element,Node:win.Node,CustomEvent:win.CustomEvent,MutationObserver:win.MutationObserver,getComputedStyle:win.getComputedStyle.bind(win),requestAnimationFrame:cb=>setTimeout(cb,0),cancelAnimationFrame:clearTimeout,IS_REACT_ACT_ENVIRONMENT:true}))Object.defineProperty(globalThis,name,{value,writable:true,configurable:true});
for(const name of ['HTMLFormElement','HTMLInputElement','HTMLButtonElement','HTMLSelectElement','HTMLTextAreaElement','Event','KeyboardEvent','MouseEvent','PointerEvent','FocusEvent','DocumentFragment','NodeFilter'])if(win[name])Object.defineProperty(globalThis,name,{value:win[name],writable:true,configurable:true});
win.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){},addListener(){},removeListener(){}});Object.defineProperty(win,'isSecureContext',{value:true});
Object.defineProperty(win.navigator,'geolocation',{value:{getCurrentPosition:()=>{throw Error('Location must not be requested');}}});
let sub=null,asked=0;const subscription={endpoint:'https://web.push.apple.com/test-device',toJSON:()=>({endpoint:'https://web.push.apple.com/test-device',keys:{p256dh:'A'.repeat(87),auth:'B'.repeat(22)}}),unsubscribe:async()=>{sub=null;return true;}};
const swListeners={};
const reg={pushManager:{getSubscription:async()=>sub,subscribe:async()=>{sub=subscription;return sub;}}};Object.defineProperty(win.navigator,'serviceWorker',{value:{register:async()=>reg,ready:Promise.resolve(reg),addEventListener(type,fn){swListeners[type]=fn;},removeEventListener(type){delete swListeners[type];}}});win.PushManager=function(){};win.Notification={permission:'default',requestPermission:async()=>{asked++;win.Notification.permission='granted';return 'granted';}};globalThis.Notification=win.Notification;
const server=await createServer({configFile:false,root:process.cwd(),plugins:[react()],resolve:{alias:[{find:'@',replacement:process.cwd()},{find:'./supabase',replacement:process.cwd()+'/tests/fixtures/supabase.ts'}]},server:{middlewareMode:true},appType:'custom'});
const {createRoot}=await import('react-dom/client');
const root=createRoot(document.getElementById('root'));
try{
 const {default:App}=await server.ssrLoadModule('/src/monster-app.tsx');const {calls}=await server.ssrLoadModule('/tests/fixtures/supabase.ts');
 await act(async()=>root.render(React.createElement(App,{userId:'test-user'})));
 assert.deepEqual([...document.querySelectorAll('.drink-option')].map(e=>e.textContent),['Monster Original','Monster Lando Norris','Monster Lewis Hamilton','Monster Ultra White']);
 assert(!document.querySelector('.amount-selector'));
 for(const option of document.querySelectorAll('.drink-option')){
  await act(async()=>option.querySelector('button').click());
  const label=option.textContent;const kind=label==='Monster Original'?'Monster Energy':label;const drink=document.querySelector('button.big-drink');
  assert.equal(drink.getAttribute('aria-label'),`500 Milliliter ${label} eintragen`);
  await act(async()=>drink.click());
  assert(calls.some(c=>c.name==='mwm_action'&&c.args.payload.kind===kind&&c.args.payload.amount===500));
 }
 assert(!document.querySelector('.location-sharing'));assert(!('location' in calls.find(c=>c.name==='mwm_action'&&c.args.payload.action==='drink').args.payload));
 await act(async()=>swListeners.message({data:{type:'mwm-drink',drinkId:'11111111-1111-4111-8111-111111111111'}}));assert.match(document.querySelector('[role="dialog"]').textContent,/Testfreund trinkt/);await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Schließen').click());
 const profile=document.querySelector('[aria-label="Profil und Tageslimit"]');await act(async()=>profile.click());assert.equal(asked,0);const buttons=[...document.querySelectorAll('button')];const enable=buttons.find(b=>b.textContent.includes('Auf diesem Gerät aktivieren'));assert(enable&&!enable.disabled);await act(async()=>enable.click());assert.equal(asked,1);assert(calls.some(c=>c.name==='mwm_push_subscribe'));const test=[...document.querySelectorAll('button')].find(b=>b.textContent.includes('Test-Mitteilung senden'));assert(test);await act(async()=>test.click());assert(calls.some(c=>c.name==='mwm_push_test'));const off=[...document.querySelectorAll('button')].find(b=>b.textContent.includes('Auf diesem Gerät ausschalten'));await act(async()=>off.click());assert.equal(sub,null);assert(calls.some(c=>c.name==='mwm_push_unsubscribe'));
 console.log('UI passed: four Monster flavors, 500 ml logging, permission only on tap, push subscription/test/disable.');
 const {default:DrinkPopup}=await server.ssrLoadModule('/src/drink-popup.tsx');const {notice,noticeResult}=await server.ssrLoadModule('/tests/fixtures/supabase.ts');let popupClosed=0;
 await act(async()=>root.render(React.createElement(DrinkPopup,{entryId:notice.id,onClose:()=>popupClosed++})));
 assert.match(document.querySelector('[role="dialog"]').textContent,/Testfreund trinkt/);assert.match(document.querySelector('[role="dialog"]').textContent,/Monster Energy/);assert.match(document.querySelector('[role="dialog"]').textContent,/500 ml/);assert(!document.querySelector('[role="dialog"] a'));assert(!document.querySelector('[role="dialog"]').textContent.includes('Standort'));await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Schließen').click());assert.equal(popupClosed,1);
 noticeResult.error={code:'42501'};noticeResult.data=null;await act(async()=>root.render(React.createElement(DrinkPopup,{entryId:'22222222-2222-4222-8222-222222222222',onClose:()=>popupClosed++})));assert.match(document.querySelector('[role="alert"]').textContent,/nicht mehr/);assert(!document.querySelector('[role="dialog"] a'));noticeResult.error=null;noticeResult.data=notice;
 console.log('Popup UI passed: friend, drink, amount, no location and unavailable/revoked access.');
 const {default:AuthForm}=await server.ssrLoadModule('/src/auth-form.tsx');const {authResult}=await server.ssrLoadModule('/tests/fixtures/supabase.ts');
 await act(async()=>root.render(React.createElement(AuthForm)));
 await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Konto erstellen').click());
 const submit=document.querySelector('button[type="submit"]');assert(!submit.disabled);assert.equal(submit.textContent,'Jetzt Konto erstellen');
 await act(async()=>submit.click());assert.match(document.querySelector('[role="status"]').textContent,/gültige E-Mail/);assert(!calls.some(c=>c.name==='signUp'));
 async function fill(name,value){const input=document.querySelector(`input[name="${name}"]`);await act(async()=>{Object.getOwnPropertyDescriptor(win.HTMLInputElement.prototype,'value').set.call(input,value);input.dispatchEvent(new win.Event('input',{bubbles:true}));});}
 await fill('email','friend@example.com');await fill('password','short');await act(async()=>submit.click());assert.match(document.querySelector('[role="status"]').textContent,/mindestens 8/);assert(!calls.some(c=>c.name==='signUp'));
 await fill('password','a-valid-password');await act(async()=>submit.click());assert(calls.some(c=>c.name==='signUp'));assert.match(document.querySelector('[role="status"]').textContent,/Spam-Ordner/);assert.match(document.querySelector('[role="status"]').textContent,/RepPilot-Konto/);assert(!submit.disabled);
 authResult.error={code:'email_address_not_authorized'};await act(async()=>submit.click());assert.match(document.querySelector('[role="status"]').textContent,/Versanddienst/);assert(!submit.disabled);
 authResult.error=null;await act(async()=>document.querySelector('.auth-tabs button').click());assert.equal(document.querySelector('button[type="submit"]').textContent,'Anmelden');await act(async()=>document.querySelector('button[type="submit"]').click());assert(calls.some(c=>c.name==='signInWithPassword'));
 console.log('Auth UI passed: clickable signup, visible validation, confirmation guidance, mail-service error, and existing account login.');
}finally{await act(async()=>root.unmount());await server.close();dom.window.close();}
