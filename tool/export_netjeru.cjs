#!/usr/bin/env node
// NTRW-SKIN-001: recovered September 11 export, verified against immutable PNGs.
// NODE_PATH=<runtime node_modules> node tool/export_netjeru.cjs OUTPUT [--export]
// CHROME_PATH may locate the pinned renderer; controls are never overwritten.
const fs = require('node:fs');
const {createHash} = require('node:crypto');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const baseline = path.join(root, 'test/visual_reference/netjeru/baseline');
const out = path.resolve(process.argv[2] || '/tmp/netjeru-export');
const keys = ['hetheru', 'khepri', 'djehuty', 'maat', 'ptah', 'sekhmet'];
const version = '154.0.8037.58';
const write = process.argv.includes('--export');
async function compare(reference, candidate, heatmap) {
  const a = await sharp(reference).raw().toBuffer({resolveWithObject:true});
  const b = await sharp(candidate).raw().toBuffer({resolveWithObject:true});
  if (JSON.stringify(a.info)!==JSON.stringify(b.info)) throw Error('Dimensions/alpha mismatch');
  const sums=[0,0,0]; let within=0,max=0;const heat=Buffer.alloc(a.data.length);
  for(let i=0;i<a.data.length;i+=3){let peak=0;for(let c=0;c<3;c++){const d=Math.abs(a.data[i+c]-b.data[i+c]);sums[c]+=d;peak=Math.max(peak,d);}max=Math.max(max,peak);if(peak<=3)within++;heat[i]=Math.min(255,peak*8);}
  const pixels=a.info.width*a.info.height;const means=sums.map(v=>v/pixels);
  await sharp(heat,{raw:{width:a.info.width,height:a.info.height,channels:3}}).png().toFile(heatmap);
  // Strict subset of rev5: no >3 differences anywhere, so no AA exemption needed.
  return {dimensions:[a.info.width,a.info.height],channels:a.info.channels,mean:means,within3:within/pixels,max,pass:means.every(v=>v<=.5)&&within/pixels>=.995&&max<=3};
}
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({executablePath:process.env.CHROME_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--disable-gpu','--hide-scrollbars']});
 try {
  if(await browser.version()!==version)throw Error(`Renderer must be ${version}; revalidate before changing it`);
  const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true});
  const cdp=await page.context().newCDPSession(page);
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true,screenWidth:390,screenHeight:844});
  await page.goto(pathToFileURL(path.join(baseline,'original-export.html')).href);
  await page.addStyleTag({content:'.netjer-card{border-color:transparent!important;border-radius:0!important}.netjer-card > :not(.netjer-art){visibility:hidden!important}.netjer-card:after{display:none!important}'});
  async function capture(key,source,destination,palette={}){
   await page.evaluate(k=>document.querySelector(`.netjer-card[data-key="${k}"]`).click(),key);
   await page.waitForTimeout(300);
   const el=page.locator(`.netjer-card[data-key="${key}"] .netjer-art`);
   await el.evaluate((el,{svg,palette})=>{el.innerHTML=svg;for(const [name,colors] of Object.entries(palette))colors.forEach((color,i)=>el.style.setProperty(`--${name}-${i}`,color));},{svg:fs.readFileSync(source,'utf8'),palette});
   await el.scrollIntoViewIfNeeded();
   const rect=await el.evaluate(el=>{const r=el.getBoundingClientRect();return{x:r.left+scrollX,y:r.top+scrollY,width:r.width,height:r.height}});
   const shot=await cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{...rect,scale:1}});
   fs.writeFileSync(destination,Buffer.from(shot.data,'base64'));
  }
  const results={renderer:version,playwright:require('playwright/package.json').version,viewport:[390,844],deviceScaleFactor:2,artSize:[304,406],results:{}};
  for(const key of keys){const dest=path.join(out,`${key}-baseline.png`);await capture(key,path.join(baseline,key+'.svg'),dest);results.results[key]=await compare(path.join(baseline,key+'.png'),dest,path.join(out,key+'-heatmap.png'));}
  fs.writeFileSync(path.join(out,'parity.json'),JSON.stringify(results,null,2));
  if(!Object.values(results.results).every(r=>r.pass))throw Error('Export parity failed; no edited figure exported');
  console.log('All six baseline figures pass (including both controls).');
  const palettePath=path.join(root,'assets/the_kar/netjeru_palette.json');
  if(fs.existsSync(palettePath)){
   const palette=JSON.parse(fs.readFileSync(palettePath,'utf8'));
   const assets={hetheru:'assets/the_kar/hetheru.png',khepri:'assets/the_kar/khepri.png'};
   for(const key of keys.slice(2)){const dest=path.join(out,key+'.png');await capture(key,path.join(root,'assets/the_kar',key+'.svg'),dest,palette);const digest=createHash('sha256').update(fs.readFileSync(dest)).digest('hex').slice(0,16);assets[key]=`assets/the_kar/${key}-${digest}.png`;if(write)fs.copyFileSync(dest,path.join(root,assets[key]));}
   if(write)fs.writeFileSync(path.join(root,'lib/features/calendar/the_kar/netjeru_art_assets.dart'), '// Generated by tool/export_netjeru.cjs. Content hashes match immutable asset URLs.\nconst netjeruArtAssets = <String, String>{\n'+Object.entries(assets).map(([key,value])=>`  '${key}': '${value}',\n`).join('')+'};\n');
  }
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
