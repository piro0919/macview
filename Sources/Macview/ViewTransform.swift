import CoreGraphics

/// How the picture currently sits in the window: which way up, which way round, how big.
/// Every image starts fitted and unturned; the state is dropped when another image is opened.
struct ViewTransform {
    /// Quarter turns clockwise, 0...3.
    var quarterTurns = 0
    /// Left to right.
    var mirrored = false
    /// Top to bottom.
    var flipped = false
    /// Points per image pixel. Nil means "as large as the window allows".
    var scale: CGFloat?
    var offset = CGPoint.zero

    /// qView's own numbers: a quarter more or less at a time, and zooming past actual size allowed.
    static let step: CGFloat = 1.25
    static let minScale: CGFloat = 0.02
    static let maxScale: CGFloat = 64

    mutating func turn(by turns: Int) {
        quarterTurns = ((quarterTurns + turns) % 4 + 4) % 4
        offset = .zero
    }
}

/// The arithmetic behind the view, kept apart from AppKit so it can be checked without a window.
enum Layout {
    /// The picture's size once turned, still in image pixels.
    static func turnedSize(_ size: CGSize, quarterTurns: Int) -> CGSize {
        quarterTurns % 2 == 0 ? size : CGSize(width: size.height, height: size.width)
    }

    /// The scale that fits the picture in the window without enlarging it.
    static func fitScale(pixelSize: CGSize, quarterTurns: Int, in bounds: CGSize) -> CGFloat {
        let turned = turnedSize(pixelSize, quarterTurns: quarterTurns)
        guard turned.width > 0, turned.height > 0, bounds.width > 0, bounds.height > 0 else {
            return 1
        }
        return min(bounds.width / turned.width, bounds.height / turned.height, 1)
    }

    /// Centred while the picture is smaller than the window, and never dragged past its own
    /// edges while it is larger.
    static func clamp(offset: CGPoint, displayed: CGSize, in bounds: CGSize) -> CGPoint {
        func axis(_ value: CGFloat, _ size: CGFloat, _ limit: CGFloat) -> CGFloat {
            let slack = (size - limit) / 2
            return slack <= 0 ? 0 : min(max(value, -slack), slack)
        }
        return CGPoint(
            x: axis(offset.x, displayed.width, bounds.width),
            y: axis(offset.y, displayed.height, bounds.height)
        )
    }

    /// Zooming under the pointer: whatever the cursor was over stays under the cursor.
    static func offsetAnchoring(
        cursor: CGPoint,
        in bounds: CGSize,
        offset: CGPoint,
        oldDisplayed: CGSize,
        newDisplayed: CGSize
    ) -> CGPoint {
        guard oldDisplayed.width > 0, oldDisplayed.height > 0 else { return offset }
        let centre = CGPoint(x: bounds.width / 2 + offset.x, y: bounds.height / 2 + offset.y)
        let held = CGPoint(
            x: (cursor.x - (centre.x - oldDisplayed.width / 2)) / oldDisplayed.width,
            y: (cursor.y - (centre.y - oldDisplayed.height / 2)) / oldDisplayed.height
        )
        return CGPoint(
            x: cursor.x - (held.x - 0.5) * newDisplayed.width - bounds.width / 2,
            y: cursor.y - (held.y - 0.5) * newDisplayed.height - bounds.height / 2
        )
    }
}
