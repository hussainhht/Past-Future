# Four-view reference study

The source images are `frontview.png`, `backview.png`, `sideview1.png`, and
`sideview2.png` in `../references/`. Each is 1024 × 572. They remain unchanged.
Anatomical left/right below always means the character's left/right.

## Proportions and silhouette

The front silhouette occupies approximately x=373–666, y=28–547. These are
manually observed image landmarks, not reconstructed camera calibration.
The top hair tip to chin is about 217 pixels, or 42% of the total visible
height. Total height is therefore about 2.4 visible head lengths including
the tall hairstyle. The face alone runs from the hairline near y=102 to
the chin near y=245. The cheek/ear span is about 190 pixels; the central
jacket body is about 163 pixels across at its hem. Hair spans about 207
pixels across. The broad head and compact body are essential to the identity.

Front landmarks: collar at y=238–273, shoulders around y=265, jacket hem
y=415–418, wrists around y=381, hanging fingers y=440, trouser/boot
transition y=480, soles around y=544. Both boots are broad with short toes.
The knees are not strongly marked and the trousers are short, chunky,
and slightly baggy above the boot shafts.

The arms rest slightly away from the torso. The upper sleeves slope out
from the shoulders, then the forearms descend almost vertically. Hands
are compact rounded forms with clearly separate thumbs and small finger
divisions. Side views show a rounded chest and abdomen, nearly vertical
back, and a head whose chin projects a little ahead of the collar.

## Face and hair

The head is soft, rounded, and broad at the cheeks, tapering gently to a
rounded chin; it is not a cube, sphere, or long adult head. Skin is warm
peach tan. Ears are rounded with recessed inner bowls, at eye/nose height.
The nose is small but projects in profile; it has a rounded tip and soft
nostrils. Two dark brown vertical oval eyes are set directly in the face,
with no prominent white sclera. Broad charcoal eyebrows have gently
raised outer curves. The mouth is a short, subtle closed line with a
slight smile. There is no beard or facial ornament.

The charcoal hair is a sculpted stack of curved, tapered locks, with
subtle warmer highlights. A tall central/rear tuft rises at the crown.
Several swept locks flow outward at the upper sides. The foremost curved
lock falls toward the character's left forehead, with several smaller
locks over the opposite temple. Long back locks overlap in staggered
rows and terminate at the nape near the raised jacket collar. Both side
views confirm thick hair depth behind the ear and a pointed temple lock.
Individual locks have rounded ridges, not polygonal spikes or flat strips.

## Clothing and asymmetric details

The mustard/ochre field jacket is open through the front, with a raised
collar, placket edges, a lightly padded rolled hem, and rolled cuffs below
the elbows. A cream/off-white henley is visible through the opening:
short split neckline, overlapping placket, and small buttons. The lower
front pockets are subtle slanted welt openings. The anatomical-right
chest has a rounded rectangular flap pocket with one central button.
The anatomical-left chest carries a clipped ID card over a small backing
pocket. The ID has a blue-grey clip, tiny portrait block, and sparse
dark blue lines; legible invented text is unnecessary.

The anatomical-left upper sleeve has a small rectangular flap pocket
with a central button. The other sleeve is relatively plain. The sleeve
attachment and collar seams are quiet rounded changes of form. Jacket
buttons are muted bronze/brown rather than bright gold. Trousers are
charcoal blue. Brown leather ankle boots have darker soles, short raised
heels, front tongue panels, several crossed laces, and soft seams.

A broad brown leather strap passes from the anatomical-right shoulder
to the anatomical-left hip. On the front it crosses over the right
chest pocket's inner edge and the shirt, passing below the left ID. On
the back it slopes from the right shoulder toward the left hip. The
left hip carries a rounded brown leather messenger satchel, its top
near the cuff/wrist and base near upper thigh. It has a folded top flap,
edge seams, strap attachments, and small dull-metal buckles/studs.
The left wrist has a brown leather watch strap, round pale metal case,
and light dial with sparse markings.

## Consistency between views

`sideview1.png` shows the anatomical-right profile facing image-right;
the satchel is mostly hidden on the far side. `sideview2.png` shows the
anatomical-left profile facing image-left, with the watch, sleeve pocket,
and satchel clearly exposed. These views resolve accessory laterality.
The front and back agree on strap direction. Small changes in exact lock
tips, collar height, sleeve wrinkle placement, and boot lace alignment
are treated as image-generation inconsistencies; preserve their shared
silhouette and construction rather than invent additional accessories.

## Review camera and limits

The reference is close to an orthographic studio product view with a
small downward camera angle. The review uses a 3° elevated orthographic
camera, 1024 × 572 output, and a camera height that places the model
within about 90% of the frame height. These are visual approximations:
the source camera focal length, exact pose, and lighting are unknown.
The comparison tool places the unchanged source image beside the actual
Godot render, without repainting or manually warping the model image.

Technical validation (bone mapping, normalized weights, clip counts,
source file hashes, runtime actions, LAN) is independent of visual
fidelity. Compare all four silhouettes, inspect the two three-quarter
views, and review temporal animation montages and gameplay captures.
