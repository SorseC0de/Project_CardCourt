import pathlib, re, sys, json

root = pathlib.Path(sys.argv[1])
source = root / "_Graphic Assets/Vectors/Swisshbone.svg"
assets = root / "ProjectCardCourt/Assets.xcassets"

# Zuphy32, in the order CardCourt_Palette.png lists it — read off the file rather than
# typed from memory, so a ramp can be written the way it is thought about: by index.
PALETTE = [
    "472D3C", "5E3643", "7A444A", "A05B53", "BF7958", "EEA160", "F4CCA1", "B6D53C",
    "71AA34", "397B44", "3C5956", "302C2E", "5A5353", "7D7071", "A0938E", "CFC6B8",
    "DFF6F5", "8AEBF1", "28CCDF", "3978A8", "394778", "39314B", "564064", "8E478C",
    "CD6093", "FFAEB6", "F4B41B", "F47E1B", "D26D19", "E6482E", "A93B3B", "827094",
]

def rgb(index):
    hexed = PALETTE[index]
    return "rgb({},{},{})".format(*(int(hexed[i:i + 2], 16) for i in (0, 2, 4)))

def sourceColours(art):
    """The drawing's own four, lightest first.

    **Read off the file, not looked up.** They were written as palette 15, 14, 13, 12 —
    and three of them are, but the third is #7E6F70 against the palette's #7D7071, one off
    in every channel. Naming the source by index missed it and left that band unrecoloured
    in every variant. The file is the authority on what the file contains.
    """
    found = set(re.findall(r"rgb\(\d+,\d+,\d+\)", art))
    def light(colour):
        return sum(int(n) for n in re.findall(r"\d+", colour))
    return sorted(found, key=light, reverse=True)

# A variant is four palette indices, light to dark. Anything else would be a colour the
# rest of the game cannot use.
RAMPS = {
    "Swisshbone":        [15, 14, 13, 12],
    "SwisshboneGold":    [6, 26, 4, 1],
    "SwisshboneCopper":  [6, 5, 4, 1],
    "SwisshboneCrystal": [16, 17, 18, 22],
}

art = source.read_text()
bone = sourceColours(art)
assert len(bone) == 4, f"expected four fills, found {len(bone)}: {bone}"
for name, ramp in RAMPS.items():
    out = art
    for was, now in zip(bone, ramp):
        out = out.replace(was, rgb(now))
    folder = assets / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.svg").write_text(out)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        # Not template-rendered: the shading *is* the asset, and a template would flatten
        # all four into one colour.
        "properties": {"preserves-vector-representation": True},
    }, indent=2) + "\n")
    print(f"{name:20} {' · '.join(str(i) for i in ramp)}")
