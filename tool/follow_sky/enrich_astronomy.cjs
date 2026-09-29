// Regenerate only graphicAstronomy fields. Run from the RC checkout with:
// NODE_PATH=<temporary install>/node_modules node tool/follow_sky/enrich_astronomy.cjs
// npm dependency: astronomy-engine@2.1.19 (no runtime Flutter dependency).
const fs = require('fs');
const A = require('astronomy-engine');
if (JSON.parse(fs.readFileSync(require('path').join(require('path').dirname(require.resolve('astronomy-engine')), 'package.json'))).version !== '2.1.19') throw Error('Pinned engine required');
const path = 'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json';
const catalog = JSON.parse(fs.readFileSync(path));
const round = n => Number(n.toFixed(9));
const hour = 3600000;
// Typical physical shower parameters from IMO 2026 table 5 and AMS calendar.
// Widths are declared qualitative-envelope approximations, not forecasts.
// Peak dates and enhanced intervals are intentionally NOT sourced here.
const showers = {
  orionids: ['Orion',95,16,66,20,'moderate',18,'ordinary','notable'],
  'southern-taurids': ['Taurus',52,15,27,5,'plateau',120,'notable','low'],
  'northern-taurids': ['Taurus',58,22,29,5,'plateau',96,'notable','low'],
  leonids: ['Leo',152,22,71,15,'moderate',12,'ordinary','notable'],
  geminids: ['Gemini',112,33,35,150,'broad',24,'ordinary','low'],
  ursids: ['Ursa Minor',217,76,33,10,'moderate',12,'low','low'],
  quadrantids: ['Boötes',230,49,41,120,'narrow',3,'notable','low'],
  lyrids: ['Lyra',271,34,49,18,'moderate',12,'ordinary','low'],
  'eta-aquariids': ['Aquarius',338,-1,66,50,'broad',72,'low','notable'],
  'southern-delta-aquariids': ['Aquarius',340,-16,41,25,'broad',72,'low','low'],
  'alpha-capricornids': ['Capricornus',307,-10,23,5,'plateau',72,'notable','low'],
  perseids: ['Perseus',48,58,59,100,'broad',24,'notable','notable'],
};
// Eclipse type and diameter/penumbral/umbral magnitudes: NASA GSFC catalogs.
const solar = {
  'solar-eclipse-2027-02-06': ['annular',0.9281],
  'solar-eclipse-2027-08-02': ['total',1.0790],
  'solar-eclipse-2028-01-26': ['annular',0.9208],
};
const lunar = {
  'lunar-eclipse-2026-08-28': ['partial',0.9299,1.9645],
  'lunar-eclipse-2027-02-20': ['penumbral',-0.0569,0.9266],
  'lunar-eclipse-2027-07-18': ['penumbral',-1.0680,0.0014],
  'lunar-eclipse-2027-08-17': ['penumbral',-0.5254,0.5456],
  'lunar-eclipse-2028-01-12': ['partial',0.0662,1.0468],
};
// Planet physical radii in km: NASA planetary fact sheets (equatorial disks).
const radii = {Mercury:2439.7,Venus:6051.8,Mars:3396.2,Jupiter:71492,Saturn:60268};
function appearance(body,t) {
  const i=A.Illumination(body,t);
  return {body:body.toLowerCase(), angularDiameterArcseconds:round(2*Math.atan(radii[body]/(i.geo_dist*149597870.7))*180/Math.PI*3600), apparentMagnitude:round(i.mag)};
}
const meteorEphemerides = {};
for (const e of catalog.events) {
  const t=new Date(e.instantUtc || (new Date(e.peakWindowUtc.startUtc).getTime()+new Date(e.peakWindowUtc.endUtc).getTime())/2);
  const g={source:'Astronomy Engine',sourceVersion:'2.1.19',calculationVersion:'sky-graphic-astronomy-v1',provisional:!!e.provisional};
  if(e.kind==='meteorShower') {
    const key=e.id.replace(/-\d{4}$/,'');
    const p=showers[key]; if(!p) throw Error('Missing shower '+e.id);
    g.source='IMO working list + AMS shower characteristics + Astronomy Engine';
    g.sourceVersion='IMO 2026 table 5; AMS 2026/2027; engine 2.1.19; typical-envelope-v1';
    const [constellation,ra,dec,velocityKmPerSecond,zenithalHourlyRate,peakShape,halfMaximumHours,fireballs,trains]=p;
    // Rotate the catalog J2000 mean radiant into equator-of-date coordinates.
    const vector=A.VectorFromSphere(new A.Spherical(dec,ra,1),t);
    const eq=A.EquatorFromVector(A.RotateVector(A.Rotation_EQJ_EQD(t),vector));
    g.meteor={constellation,rightAscensionDegrees:round(eq.ra*15),declinationDegrees:round(eq.dec),velocityKmPerSecond,zenithalHourlyRate,peakShape,halfMaximumHours,fireballs,trains};
    const epoch=new Date(t.getTime()-48*hour);g.epochUtc=epoch.toISOString();g.ephemeris=[];
    for(let h=0;h<=96;h++) {
      const at=new Date(epoch.getTime()+h*hour),rot=A.Rotation_EQJ_EQD(at);
      const m=A.RotateVector(rot,A.GeoVector('Moon',at,true));
      const s=A.RotateVector(rot,A.GeoVector('Sun',at,true));
      g.ephemeris.push([h,A.SiderealTime(at)*15,m.x,m.y,m.z,A.Illumination('Moon',at).phase_fraction,s.x,s.y,s.z].map(round));
    }
  } else if(e.kind==='solarEclipse') {
    const [type,magnitude]=solar[e.id];g.source='NASA GSFC solar eclipse catalog';g.sourceVersion='Five Millennium Canon 2001–2100';
    g.solarEclipse={type,magnitude,lunarSolarRadiusRatio:magnitude};
  } else if(e.kind==='lunarEclipse') {
    const [type,umbralMagnitude,penumbralMagnitude]=lunar[e.id];g.source='NASA GSFC lunar eclipse catalog';g.sourceVersion='Five Millennium Canon 2001–2100';
    g.lunarEclipse={type,umbralMagnitude,penumbralMagnitude};
  } else if(e.kind==='planetOpposition'||e.kind==='planetElongation') {
    // Stable catalog IDs are ingest keys only. No display-title parsing.
    const id=e.id.split('-')[0];const body=Object.keys(radii).find(b=>b.toLowerCase()===id);
    if(!body)throw Error(e.id);g.planets=[appearance(body,t)];
    if(e.kind==='planetElongation') {
      const elongation=A.Elongation(body,t);g.elongationDegrees=round(elongation.elongation);
      g.elongationDirection=elongation.visibility==='morning'?'western':'eastern';
    }
  } else if(e.kind==='planetConjunction') {
    const keys=e.id.split('-').slice(0,2);const bodies=keys.map(id=>Object.keys(radii).find(b=>b.toLowerCase()===id));
    g.planets=bodies.map(b=>appearance(b,t));g.separations=[];
    for(let h=-72;h<=72;h+=3) {
      const at=new Date(t.getTime()+h*hour);
      g.separations.push([h,round(A.AngleBetween(A.GeoVector(bodies[0],at,true),A.GeoVector(bodies[1],at,true)))]);
    }
    g.minimumSeparationDegrees=g.separations.find(r=>r[0]===0)[1];
  } else continue;
  if(g.ephemeris) { meteorEphemerides[e.id]=g.ephemeris; delete g.ephemeris; }
  e.graphicAstronomy=g;
}
// The main catalog stays small for discovery/calendar loading. Bulk immutable
// ephemerides are generated Dart constants, loaded only by graphic geometry.
const blocks=[];
for(const e of catalog.events) {
  const {graphicAstronomy,...original}=e;
  let block=JSON.stringify(original,null,2);
  if(graphicAstronomy) block=block.slice(0,-2)+',\n  "graphicAstronomy": '+JSON.stringify(graphicAstronomy)+'\n}';
  blocks.push(block.split('\n').map(l=>'    '+l).join('\n'));
}
const header=JSON.stringify({...catalog,events:[]},null,2);
fs.writeFileSync(path,header.replace('"events": []','"events": [\n'+blocks.join(',\n')+'\n  ]')+'\n');
let dart='// GENERATED by tool/follow_sky/enrich_astronomy.cjs; Astronomy Engine 2.1.19.\n'
  +'// Geocentric EQD Moon/Sun samples. Catalog holds epochs and provenance.\n'
  +'const Map<String, List<List<double>>> meteorGraphicEphemerides = {\n';
for(const [id,rows] of Object.entries(meteorEphemerides)) {
  dart+=`  '${id}': [\n`+rows.map(row=>'    ['+row.map(n=>Number.isInteger(n)?n+'.0':n).join(', ')+'],').join('\n')+'\n  ],\n';
}
dart+='};\n';
fs.writeFileSync('lib/features/calendar/follow_the_sky/services/sky_graphic_ephemeris.g.dart',dart);
console.log('Enriched '+catalog.events.filter(e=>e.graphicAstronomy).length+' events; scheduling and copy retained.');
// Independent engine API fixtures exercise the app's own EQD -> horizon code.
const referenceEvent=catalog.events.find(e=>e.id==='orionids-2026');
const referenceMeteor=referenceEvent.graphicAstronomy.meteor;
const references=[];
for(const [latitude,longitude,zone] of [[34.0522,-118.2437,'America/Los_Angeles'],[-33.8688,151.2093,'Australia/Sydney'],[51.5074,-0.1278,'Europe/London']]) {
  for(const at of ['2026-10-21T06:00:00Z','2026-10-21T10:30:00Z','2026-10-21T14:00:00Z']) {
    const t=new Date(at),o=new A.Observer(latitude,longitude,0);
    const m=A.Equator('Moon',t,o,true,true),s=A.Equator('Sun',t,o,true,true);
    const mh=A.Horizon(t,o,m.ra,m.dec),sh=A.Horizon(t,o,s.ra,s.dec);
    const r=A.Horizon(t,o,referenceMeteor.rightAscensionDegrees/15,referenceMeteor.declinationDegrees);
    references.push({event:referenceEvent.id,latitude,longitude,zone,at,
      radiantAltitude:r.altitude,radiantAzimuth:r.azimuth,moonAltitude:mh.altitude,
      sunAltitude:sh.altitude,illumination:A.Illumination('Moon',t).phase_fraction});
  }
}
fs.writeFileSync('test/fixtures/follow_sky/graphic_geometry_engine_2_1_19.json',JSON.stringify(references,null,2));
