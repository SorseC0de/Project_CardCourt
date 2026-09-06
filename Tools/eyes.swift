// Proves the eye table can be written down and read back.
//
// A tuning pass is an evening's work at a phone, and the one way to waste it is a dump
// that loses something. This places cells the way the gallery does — a still sheet, a
// spread with two corrections, an eye switched off, and a sheet deliberately half done —
// dumps them as source, parses that source back, and checks every cell reads identical.
//
// Compiles `EyeTable.swift` itself rather than a copy of it, so it cannot drift.

import Foundation
import CoreGraphics

// A realistic pass: a still sheet placed once and spread; a 16-frame sheet spread then
// corrected on two cells; a sheet with one eye switched off; a sheet only half done.
let sheets: [(name: String, frames: Int)] = [
    ("Player_front", 1), ("Player_front_spinball", 4), ("Player_Run_Look", 16),
    ("Player_right", 1), ("Player_Wave", 16), ("Player_back", 1),
]
var table: [String: EyeSpot] = [:]
func place(_ sheet: String, _ frame: Int, _ eye: Eye, _ spot: EyeSpot) {
    table["\(sheet)/\(frame)/\(eye.rawValue)"] = spot
}

place("Player_front", 0, .near, EyeSpot(x: 0, y: 1))
place("Player_front", 0, .far, EyeSpot(x: 0, y: 1))
for f in 0..<4 {
    place("Player_front_spinball", f, .near, EyeSpot(x: 1, y: 0))
    place("Player_front_spinball", f, .far, EyeSpot(x: 1, y: 0))
}
for f in 0..<16 {
    place("Player_Run_Look", f, .near, EyeSpot(x: 2, y: 0))
    place("Player_Run_Look", f, .far, EyeSpot(x: 2, y: -1))
}
place("Player_Run_Look", 7, .far, EyeSpot(x: 2, y: -2))
place("Player_Run_Look", 8, .far, EyeSpot(shown: false))
place("Player_right", 0, .near, EyeSpot(x: -1, y: 0))
place("Player_right", 0, .far, EyeSpot(shown: false))
// Half-done on purpose: three of sixteen cells placed, so no wildcard may be written.
for f in 0..<3 { place("Player_Wave", f, .near, EyeSpot(x: 3, y: 0)) }

let source = EyeTable.source(from: table, sheets: sheets)
print(source)
print("\n— lines: \(source.split(separator: "\n").count), table entries: \(table.count)")

// **Does what comes out read back as what went in?** Every cell of every sheet, through
// the same lookup the game uses, against a table parsed out of the dumped source.
var parsed: [String: EyeSpot] = [:]
for line in source.split(separator: "\n") {
    guard let key = line.split(separator: "\"").dropFirst().first,
          let x = line.range(of: "x: "), let y = line.range(of: "y: "),
          let shown = line.range(of: "shown: ") else { continue }
    func number(_ from: Range<String.Index>) -> CGFloat {
        CGFloat(Double(line[from.upperBound...].prefix { "-0123456789.".contains($0) }) ?? 0)
    }
    parsed[String(key)] = EyeSpot(
        x: number(x), y: number(y),
        shown: line[shown.upperBound...].hasPrefix("true"))
}

var bad = 0
for sheet in sheets {
    for frame in 0..<sheet.frames {
        for eye in Eye.allCases {
            let wanted = EyeTable.spot(sheet.name, frame: frame, eye: eye, in: table)
            let got = EyeTable.spot(sheet.name, frame: frame, eye: eye, in: parsed)
            if wanted != got {
                bad += 1
                print("MISMATCH \(sheet.name)/\(frame)/\(eye.rawValue): "
                      + "set \(String(describing: wanted)) read \(String(describing: got))")
            }
        }
    }
}
print(bad == 0 ? "\nROUND TRIP OK — every placed cell reads back identical"
               : "\n\(bad) CELL(S) WRONG")
