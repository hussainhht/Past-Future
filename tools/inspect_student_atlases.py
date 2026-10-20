"""Inspect alpha silhouettes and write atlas regions; source PNGs stay unchanged.
Run after the eight imagegen cutout atlases have been copied into the project.
"""
from collections import deque
from pathlib import Path
import json
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
DIRECTIONS = ['south', 'south_west', 'west', 'north_west', 'north', 'north_east', 'east', 'south_east']

def silhouette_bounds(alpha):
    width, height = alpha.size
    pixels = bytearray(1 if x >= 96 else 0 for x in alpha.getdata())
    best = None
    for start, value in enumerate(pixels):
        if not value:
            continue
        queue = deque([start]); pixels[start] = 0
        xmin = xmax = start % width; ymin = ymax = start // width; count = 0
        while queue:
            i = queue.popleft(); x = i % width; y = i // width; count += 1
            xmin = min(xmin, x); xmax = max(xmax, x); ymin = min(ymin, y); ymax = max(ymax, y)
            for n in ((i-1 if x else -1), (i+1 if x+1 < width else -1), i-width, i+width):
                if 0 <= n < len(pixels) and pixels[n]:
                    pixels[n] = 0; queue.append(n)
        if best is None or count > best[0]:
            best = (count, (max(0,xmin-2), max(0,ymin-2), min(width,xmax+3), min(height,ymax+3)))
    if best is None or best[0] < 100:
        raise ValueError('Missing or empty illustrated part')
    return best[1]


def main():
    regions = {}
    anchors = {}
    for direction in DIRECTIONS:
        image = Image.open(PROJECT / f'assets/characters/student_2d/{direction}_parts.png').convert('RGBA')
        alpha = image.getchannel('A'); cells = []; joint_anchors = []
        for part in range(16):
            col, row = part % 4, part // 4
            x0, y0 = round(col*image.width/4), round(row*image.height/4)
            x1, y1 = round((col+1)*image.width/4), round((row+1)*image.height/4)
            x, y, r, b = silhouette_bounds(alpha.crop((x0,y0,x1,y1)))
            # The illustrated forearms include cuff overlap, already supplied by the upper sleeve.
            if part in (4,6,13,14):
                y += round((b-y)*.20)
            if part in (7,9):
                b -= round((b-y)*.055)
            if part in (8,10):
                y += round((b-y)*.025)
            cells.append([x0+x,y0+y,r-x,b-y])
            crop = alpha.crop((x0+x,y0+y,x0+r,y0+b))
            def row_center(fraction):
                yy = min(crop.height-1,max(0,round((crop.height-1)*fraction)))
                xs = [xx for xx in range(crop.width) if crop.getpixel((xx,yy)) >= 96]
                return ((min(xs)+max(xs))/2/crop.width) if xs else .5
            if part in (3,5):
                top, bottom = .14, .88
            elif part in (4,6,13,14):
                top, bottom = .03, .88
            elif part in (7,9):
                top, bottom = .035, .965
            elif part in (8,10):
                top, bottom = .035, .99
            else:
                top, bottom = .03, .97
            end_x = row_center(.57) if part in (8,10) else row_center(bottom)
            joint_anchors.append([[row_center(top),top],[end_x,bottom]])
        regions[direction] = cells
        anchors[direction] = joint_anchors
        print(f'{direction}: {image.width}x{image.height}, 16 illustrated parts')
    torso_image = Image.open(PROJECT / 'assets/characters/student_2d/torso_corrections.png').convert('RGBA')
    torso_alpha = torso_image.getchannel('A')
    torso_regions = {}
    for i, direction in enumerate(DIRECTIONS):
        x0,y0 = round((i%4)*torso_image.width/4),round((i//4)*torso_image.height/2)
        x1,y1 = round((i%4+1)*torso_image.width/4),round((i//4+1)*torso_image.height/2)
        x,y,r,b = silhouette_bounds(torso_alpha.crop((x0,y0,x1,y1)))
        torso_regions[direction] = [x0+x,y0+y,r-x,b-y]
    formatted = json.dumps(regions, indent=2)
    (PROJECT / 'assets/characters/student_2d/atlas_regions.json').write_text(formatted+'\n')
    (PROJECT / 'scripts/characters/student_atlas_regions.gd').write_text('extends RefCounted\n## Generated alpha bounds. Rebuild with tools/inspect_student_atlases.py.\n\nconst REGIONS: Dictionary = '+formatted+'\n\nconst JOINT_ANCHORS: Dictionary = '+json.dumps(anchors, indent=2)+'\n\nconst TORSO_REGIONS: Dictionary = '+json.dumps(torso_regions, indent=2)+'\n')

if __name__ == '__main__':
    main()
