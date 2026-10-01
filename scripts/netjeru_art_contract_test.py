"""NTRW-SKIN-001 visual scope checks against immutable pre-change source art."""
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/the_kar'
BASE = ROOT / 'test/visual_reference/netjeru/baseline'
FIGURES = ('djehuty', 'maat', 'ptah', 'sekhmet', 'hetheru', 'khepri')

def elements(path):
    return list(ET.parse(path).getroot().iter())

class ArtworkContract(unittest.TestCase):
    def test_controls_remain_byte_identical(self):
        for figure in ('hetheru', 'khepri'):
            for suffix in ('.png', '.svg'):
                self.assertEqual((ART/(figure+suffix)).read_bytes(), (BASE/(figure+suffix)).read_bytes())

    def test_original_outlines_and_strokes_survive_except_explicit_geometry(self):
        for figure in FIGURES:
            before = elements(BASE/(figure+'.svg'))
            after = elements(ART/(figure+'.svg'))
            for element in before:
                if element.tag not in ('path', 'ellipse', 'circle', 'rect'):
                    continue
                d = element.get('d', '')
                allowed = figure == 'maat' and d.startswith(('M154 82', 'M177 107'))
                allowed |= figure == 'ptah' and (d.startswith(('M146 176', 'M120 184', 'M173 183', 'M157 170', 'M156 170')) or element.tag == 'ellipse' and element.get('cy') == '216')
                if allowed:
                    continue
                attrs = {k:v for k,v in element.attrib.items() if k != 'fill'}
                self.assertTrue(any(x.tag == element.tag and all(x.get(k) == v for k,v in attrs.items()) for x in after), (figure, attrs))

    def test_original_gradient_directions_stops_and_backgrounds_unchanged(self):
        for figure in FIGURES:
            before = elements(BASE/(figure+'.svg'))
            after = {x.get('id'):x for x in elements(ART/(figure+'.svg')) if x.get('id')}
            for gradient in before:
                if gradient.tag not in ('linearGradient', 'radialGradient'):
                    continue
                self.assertEqual(ET.tostring(gradient).strip(), ET.tostring(after[gradient.get('id')]).strip())

    def test_ptah_grip_and_sceptre_follow_spec(self):
        items = elements(ART/'ptah.svg')
        by_id = {x.get('id'):x for x in items}
        self.assertEqual(by_id['ptah-sceptre'].get('d'), 'M147 149 V306')
        for name, fraction in [('ptah-upper-fist', .22), ('ptah-lower-fist', .33)]:
            fist = by_id[name]
            self.assertAlmostEqual(float(fist.get('x')) + float(fist.get('width'))/2, 147)
            self.assertAlmostEqual(float(fist.get('y')) + float(fist.get('height'))/2, 169+125*fraction)
            self.assertEqual(fist.get('stroke'), 'var(--skinMale-3)')
            self.assertEqual(fist.get('stroke-opacity'), '.55')
        self.assertFalse(any(x.tag == 'ellipse' and x.get('cy') == '216' for x in items))
        self.assertFalse(any(x.get('d','').startswith(('M146 176','M120 184','M173 183','M157 170','M156 170')) for x in items))

    def test_maat_single_face_and_subtle_plane(self):
        items = elements(ART/'maat.svg')
        self.assertFalse(any(x.get('d','').startswith('M177 107') for x in items))
        faces = [x for x in items if x.get('d','').startswith('M154 82') and x.get('fill')]
        self.assertEqual(len(faces), 1)
        self.assertEqual(faces[0].get('fill'), 'url(#maFace)')
        gradient = next(x for x in items if x.get('id') == 'maFace')
        self.assertEqual(gradient.get('x1'), '.16')
        self.assertEqual(gradient.get('y2'), '.98')
        self.assertTrue(gradient.get('gradientTransform').startswith('matrix(43 0 0 '))
        self.assertNotIn('L188 101', faces[0].get('d'))
        plane = next(x for x in items if x.get('id') == 'maat-lower-face-plane')
        self.assertEqual(plane.get('fill-opacity'), '.07')
        self.assertEqual(plane.get('stroke'), 'none')
        blur = next(x for x in items if x.tag == 'feGaussianBlur')
        self.assertAlmostEqual(float(blur.get('stdDeviation')), .08*20)

    def test_palette_references_resolve(self):
        palette=json.loads((ART/'netjeru_palette.json').read_text())
        import re
        for figure in FIGURES:
            for name,index in re.findall(r'var\(--([A-Za-z]+)-(\d+)\)', (ART/(figure+'.svg')).read_text()):
                self.assertRegex(palette[name][int(index)], r'^#[0-9A-F]{6}$')

    def test_saved_export_parity_receipt_covers_all_six(self):
        receipt=json.loads((BASE.parent/'export-parity/parity.json').read_text())
        self.assertEqual(set(receipt['results']), set(FIGURES))
        for result in receipt['results'].values():
            self.assertTrue(result['pass'])
            self.assertEqual(result['dimensions'], [608,812])
            self.assertLessEqual(max(result['mean']), .5)
            self.assertGreaterEqual(result['within3'], .995)
            self.assertLessEqual(result['max'], 3)

if __name__ == '__main__':
    unittest.main()
