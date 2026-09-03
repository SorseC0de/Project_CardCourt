#!/bin/sh

#  ci_post_clone.sh
#  Project CardCourt
#
#  Run by Xcode Cloud after it clones the repository, before it builds.

set -e

# Xcode 26 moved the Metal compiler out of the default install and into a
# downloadable component. This project has a shader — Art/PaletteFX.metal, which
# does the uniform palette swap on the player sprites — so a build machine
# without that component fails to compile it, while a developer machine that was
# asked to download it once builds fine forever after. That asymmetry is exactly
# the "works locally, fails in CI" shape.
#
# Downloading is a no-op when the component is already present, so this is safe
# to run on every build.
echo "Ensuring the Metal toolchain is available…"
xcodebuild -downloadComponent MetalToolchain || \
    echo "Metal toolchain unavailable to download; continuing in case it is already installed."
