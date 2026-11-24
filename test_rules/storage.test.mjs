import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes } from 'firebase/storage';
import fs from 'fs';
const env = await initializeTestEnvironment({ projectId:'order-app-5957e', storage:{host:'127.0.0.1',port:9199, rules: fs.readFileSync(process.env.RULES_FILE || 'storage.rules','utf8')}});
const A='uidA', B='uidB';
const png=new Uint8Array([1,2,3]); const md={contentType:'image/png'};
const seed=async(path)=>env.withSecurityRulesDisabled(async c=>{await uploadBytes(ref(c.storage(),path),png,md);});
await seed('support_inquiries/uidA/inq1/a.png'); await seed('store_images/s.png'); await seed('x.png');
const anon=env.unauthenticatedContext().storage(), a=env.authenticatedContext(A).storage(), b=env.authenticatedContext(B).storage();
const big=new Uint8Array(6*1024*1024);
const exact5=new Uint8Array(5*1024*1024), over5=new Uint8Array(5*1024*1024+1);
const cases=[
['비로그인 문의첨부 read 거부','deny',()=>getBytes(ref(anon,'support_inquiries/uidA/inq1/a.png'))],
['로그인(타인) 문의첨부 read 허용','allow',()=>getBytes(ref(b,'support_inquiries/uidA/inq1/a.png'))],
['본인 문의첨부 read 허용','allow',()=>getBytes(ref(a,'support_inquiries/uidA/inq1/a.png'))],
['자기 경로 write 허용','allow',()=>uploadBytes(ref(a,'support_inquiries/uidA/inq2/n.png'),png,md)],
['남의 uid 경로 write 거부','deny',()=>uploadBytes(ref(b,'support_inquiries/uidA/inq2/n.png'),png,md)],
['비로그인 write 거부','deny',()=>uploadBytes(ref(anon,'support_inquiries/uidA/inq2/n.png'),png,md)],
['자기 경로 6MB 거부','deny',()=>uploadBytes(ref(a,'support_inquiries/uidA/inq2/big.png'),big,md)],
['자기 경로 정확히 5MB(5,242,880B) 허용','allow',()=>uploadBytes(ref(a,'support_inquiries/uidA/inq2/e5.png'),exact5,md)],
['자기 경로 5MB+1B 거부','deny',()=>uploadBytes(ref(a,'support_inquiries/uidA/inq2/o5.png'),over5,md)],
['자기 경로 non-image 거부','deny',()=>uploadBytes(ref(a,'support_inquiries/uidA/inq2/t.txt'),png,{contentType:'text/plain'})],
['[회귀] 비로그인 store_images read 허용','allow',()=>getBytes(ref(anon,'store_images/s.png'))],
['[회귀] 루트 파일 비로그인 read 허용','allow',()=>getBytes(ref(anon,'x.png'))],
['[회귀] 로그인 store_images write 허용','allow',()=>uploadBytes(ref(a,'store_images/n.png'),png,md)],
['[회귀] 6MB store_images write 허용(10MB 미만 현행)','allow',()=>uploadBytes(ref(a,'store_images/big.png'),big,md)],
['[회귀] 비로그인 store_images write 거부','deny',()=>uploadBytes(ref(anon,'store_images/n2.png'),png,md)],
];
let f=0;
for(const [n,e,fn] of cases){let ok;try{await fn();ok=e==='allow'}catch(x){ok=e==='deny'}console.log(ok?'PASS':'FAIL',n);if(!ok)f++}
await env.cleanup(); process.exit(f?1:0);
