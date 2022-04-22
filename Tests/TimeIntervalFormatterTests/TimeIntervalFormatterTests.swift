import XCTest
@testable import TimeIntervalFormatter

final class TimeIntervalFormatterTests: XCTestCase {
    func test_formatter() {
        let tuples = [
            (0, "0:00:00:00"), (60, "0:00:01:00"), (119, "0:00:01:59"),
            (3599, "0:00:59:59"), (3600, "0:01:00:00"), (7262, "0:02:01:02"),
            ((3600*24)-1, "0:23:59:59"), ((3600*24), "1:00:00:00"), ((3600*48)+(3600*5)+17, "2:05:00:17"),
            (31535999, "364:23:59:59"), (31536000, "365:00:00:00"), (315360001, "*:**:**:**")
        ]
        let formatter = TimeIntervalFormatter()
        formatter.style = .full
        for (t,e) in tuples {
            XCTAssertEqual(formatter.string(from: TimeInterval(t)), e)
        }
        formatter.fractionDigits = 1
        XCTAssertEqual(formatter.string(from: nil), "-:--:--:--.-")
        formatter.fractionDigits = 2
        formatter.style = .mmssf
        XCTAssertEqual(formatter.string(from: nil), "--:--.--")
        XCTAssertEqual(formatter.string(from: 123.459), "02:03.46")
        XCTAssertEqual(formatter.string(from: -123.455), "-02:03.45")
        formatter.daysSeparator = "d"
        formatter.hoursSeparator = "h"
        formatter.minutesSeparator = "m"
        formatter.secondsSeparator = "s"
        formatter.fractionSeparator = "´"
        XCTAssertEqual(formatter.string(from: 123.45), "02m03´45s")
        formatter.positiveSymbol = "+"
        XCTAssertEqual(formatter.string(from: 123.45), "+02m03´45s")
        XCTAssertEqual(formatter.string(from: 59.99), "+00m59´99s")
        formatter.fractionDigits = 1
        XCTAssertEqual(formatter.string(from: 59.999), "+01m00´0s")
        XCTAssertEqual(formatter.string(from: 120.96), "+02m01´0s")
        formatter.fractionDigits = 2
        XCTAssertEqual(formatter.string(from: 59.999), "+01m00´00s")
        formatter.fractionDigits = 3
        XCTAssertEqual(formatter.string(from: 59.999), "+00m59´999s")
        formatter.fractionDigits = 4
        XCTAssertEqual(formatter.string(from: 59.90999), "+00m59´9100s")
        formatter.style = .dhhmmssf
        formatter.fractionDigits = 1
        XCTAssertEqual(formatter.string(from: 86399.99), "+1d00h00m00´0s")
        formatter.fractionDigits = 1
        XCTAssertEqual(formatter.string(from: 86399.9), "+0d23h59m59´9s")
    }
    func test_EmptyString() {
        do {
            let formatter = TimeIntervalFormatter()
            XCTAssertEqual(formatter.timeInterval(from: ""), nil)
        }
    }
    func test_examples() {
        
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            XCTAssertEqual("**:**", formatter.string(from: TimeInterval(3600)))
        }
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            let a = TimeInterval(123.51)
            XCTAssertEqual(formatter.string(from: a), "02:04")
            let b = TimeInterval(59.51)
            XCTAssertEqual(formatter.string(from: b), "01:00")
            
            let c = TimeInterval(-123.50)
            XCTAssertEqual(formatter.string(from: c), "-02:04")
            let d = TimeInterval(-123.49)
            XCTAssertEqual(formatter.string(from: d), "-02:03")
        }
    }
    func test_fractionDigitClamping() {
        let formatter = TimeIntervalFormatter()
        formatter.fractionDigits = 2
        let tests:[(Int,Int)] = [
            (Int.min, 0), (-1, 0), (0, 0), (1, 1), (2, 2), (3, 3),
            (4, 4), (5, 5), (6, 6), (7, 6), (Int.max, 6)
        ]
        for (f,expected) in tests {
            // Write
            formatter.fractionDigits = f
            // Read
            XCTAssertEqual(formatter.fractionDigits, expected)
        }
    }
    func test_nil() {
        let formatter = TimeIntervalFormatter()
        let expected = [
            "-:--:--:--",
            "-:--:--:--.-",
            "-:--:--:--.--",
            "-:--:--:--.---",
            "-:--:--:--.----",
            "-:--:--:--.-----",
            "-:--:--:--.------",
            "-:--:--:--.------",
        ]
        for i in 0...7 {
            formatter.fractionDigits = i
            XCTAssertEqual(expected[i], formatter.string(from: nil))
        }
        formatter.fractionDigits = 1
        formatter.nanSymbol = "#"
        XCTAssertEqual("#:##:##:##.#", formatter.string(from: nil))
    }
    func test_overAndUnderflows() {
        let year = TimeInterval(60 * 60 * 24 * 365)
        let decade = year * 10
        let overflow = decade + 1.0
        let underflow = -overflow
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .full
            formatter.fractionDigits = 2
            XCTAssertEqual("365:00:00:00.00", formatter.string(from: year))
            XCTAssertEqual("3650:00:00:00.00", formatter.string(from: decade))
            XCTAssertEqual("-365:00:00:00.00", formatter.string(from: -year))
            XCTAssertEqual("-3650:00:00:00.00", formatter.string(from: -decade))
            XCTAssertEqual("*:**:**:**.**", formatter.string(from: overflow))
            XCTAssertEqual("*:**:**:**.**", formatter.string(from: underflow))
        }
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .hhmmssf
            formatter.fractionDigits = 1
            let overflows:TimeInterval = 24*60*60
            let fits:TimeInterval = 24*60*60 - 0.1
            XCTAssertEqual("**:**:**.*", formatter.string(from: overflows))
            XCTAssertEqual("-**:**:**.*", formatter.string(from: -overflows))
            XCTAssertEqual("23:59:59.9", formatter.string(from: fits))
            XCTAssertEqual("-23:59:59.9", formatter.string(from: -fits))
        }
    }
    func test_sign() {
        do {
            // positive/negative symbol tests
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            let expected:[TimeInterval?] = [
                nil, nil, 754.0,
                nil, 754.0, -754.0,
                -754.0, nil, 754.0,
                -754.0, 754.0, nil,
            ]
            var i = 0
            for n in ["", "-"] {
                formatter.negativeSymbol = n
                for p in ["", "+"] {
                    formatter.positiveSymbol = p
                    for t in ["-12:34", "+12:34", "12:34"] {
                        let ti = formatter.timeInterval(from: t)
                        /*
                        print("'\(formatter.negativeSymbol)', '\(formatter.positiveSymbol)'",
                              t,
                              "->",
                              ti ?? "nil")*/
                        XCTAssertEqual(ti, expected[i])
                        i += 1
                    }
                }
            }
        }
    }
    func test_stringToTimeInterval() {
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            formatter.fractionDigits = 3
            formatter.secondsSeparator = ""
            formatter.fractionSeparator = "."
            XCTAssertEqual(formatter.timeInterval(from: "-02:04.091"), -124.091)
            formatter.style = .hhmmssf
            XCTAssertEqual(formatter.timeInterval(from: "01:02:03.456"), 3723.456)
            formatter.style = .dhhmmssf
            XCTAssertEqual(formatter.timeInterval(from: "1:02:03:04.567"), 93784.567)
            XCTAssertEqual(formatter.timeInterval(from: "315360000:02:03:04.567"), 27247104007384.567)
            formatter.style = .required
            XCTAssertEqual(formatter.timeInterval(from: "00.123"), 0.123)
            XCTAssertEqual(formatter.timeInterval(from: "01.234"), 1.234)
            XCTAssertEqual(formatter.timeInterval(from: "12:34.567"), 754.567)
            XCTAssertEqual(formatter.timeInterval(from: "01:01:02.345"), 3662.345)
        }
    }
    func test_randomTimeIntervals() {
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .full
            for i in 0..<7 {
                formatter.fractionDigits = i
                for _ in (0..<10000) {
                    let randomInt = Int.random(in: -315360000...315360000)
                    let div = pow(10.0, TimeInterval(formatter.fractionDigits))
                    let lim = Int(div) - 1
                    let randomFrac = Int.random(in: 0...lim)
                    let random = TimeInterval(randomInt) + (TimeInterval(randomFrac) / div)
                    let str = formatter.string(from: random)
                    guard let ti = formatter.timeInterval(from: str) else {
                        XCTFail("Failed: \(str)")
                        continue
                    }
                    //print(str, "=>", random, "==", ti, "(\(i))")
                    XCTAssertEqual(random, ti, accuracy: 1.1 * (1.0/div))
                }
            }
        }
    }
    func test_debug() {
        let formatter = TimeIntervalFormatter()
        formatter.style = .full
        formatter.fractionDigits = 2
//        print(-227569629.57)
//        XCTAssertEqual(formatter.string(from: -227569629.57), "-2633:21:47:09.57")
        do {
            XCTAssertEqual(0.19, 0.29, accuracy: 0.1)
        }
    }
}
