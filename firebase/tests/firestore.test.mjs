import { before, after, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, Timestamp } from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-mymoney',firestore:{rules:readFileSync('firestore.rules','utf8')}})});
after(async()=>{await env.cleanup()});
beforeEach(async()=>{await env.clearFirestore()});
const db=(uid,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const entry=(uid)=>({amount:'12.35',currency:'EUR',date:Timestamp.now(),type:'expense',createdBy:uid,note:'Test'});
async function seed() {await env.withSecurityRulesDisabled(async c=>{
 for(const [uid,role] of [['alice','owner'],['bob','editor'],['viewer','viewer']]) await setDoc(doc(c.firestore(),`households/family/members/${uid}`),{role});
 await setDoc(doc(c.firestore(),'households/family'),{name:'Family'});
 await setDoc(doc(c.firestore(),'households/family/entries/test'),entry('alice'));
})}
test('owner can save and read private entry',async()=>{const ref=doc(db('alice'),'users/alice/entries/a');await assertSucceeds(setDoc(ref,entry('alice')));await assertSucceeds(getDoc(ref))});
test('stranger cannot read or write private entries',async()=>{await assertFails(getDoc(doc(db('bob'),'users/alice/entries/a')));await assertFails(setDoc(doc(db('bob'),'users/alice/entries/a'),entry('bob')))});
test('anonymous and unverified identities denied',async()=>{await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice/entries/a')));await assertFails(setDoc(doc(db('alice',false),'users/alice/entries/a'),entry('alice')))});
test('only existing household members can read',async()=>{await seed();await assertSucceeds(getDoc(doc(db('bob'),'households/family/entries/test')));await assertFails(getDoc(doc(db('mallory'),'households/family/entries/test')))});
test('member cannot self promote or add a stranger',async()=>{await seed();await assertFails(setDoc(doc(db('bob'),'households/family/members/bob'),{role:'owner'}));await assertFails(setDoc(doc(db('bob'),'households/family/members/mallory'),{role:'editor'}))});
test('viewer cannot write, editor can',async()=>{await seed();await assertFails(setDoc(doc(db('viewer'),'households/family/entries/new'),entry('viewer')));await assertSucceeds(setDoc(doc(db('bob'),'households/family/entries/new'),entry('bob')))});
test('cannot forge creator or change provenance',async()=>{await seed();await assertFails(setDoc(doc(db('bob'),'households/family/entries/new'),entry('alice')));await assertFails(updateDoc(doc(db('bob'),'households/family/entries/test'),{createdBy:'bob'}))});
test('malformed amounts and unexpected data rejected',async()=>{for(const payload of [{...entry('alice'),amount:12.35},{...entry('alice'),amount:'NaN'},{...entry('alice'),isAdmin:true}]) await assertFails(setDoc(doc(db('alice'),'users/alice/entries/a'),payload))});
test('revoked member immediately loses server access',async()=>{await seed();await env.withSecurityRulesDisabled(async c=>{const {deleteDoc}=await import('firebase/firestore');await deleteDoc(doc(c.firestore(),'households/family/members/bob'))});await assertFails(getDoc(doc(db('bob'),'households/family/entries/test')))});
