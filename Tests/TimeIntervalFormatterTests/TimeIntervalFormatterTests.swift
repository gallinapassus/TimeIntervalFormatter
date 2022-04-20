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
        XCTAssertEqual(formatter.string(from: 123.45), "02:03.45")
        XCTAssertEqual(formatter.string(from: -123.45), "-02:03.45")
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
    func test_examples() {
        
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            XCTAssertEqual("**:**", formatter.string(from: TimeInterval(3600)))
        }
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            formatter.fractionDigits = 2
            formatter.fractionSeparator = "´"
            XCTAssertEqual("02:03´45", formatter.string(from: TimeInterval(123.45)))
            formatter.fractionDigits = 0
            XCTAssertEqual("02:04", formatter.string(from: TimeInterval(123.51)))
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
    /*
    func test_stringToTimeInterval() {
        do {
            let formatter = TimeIntervalFormatter()
            formatter.style = .mmssf
            let expected = [
                ("12:34", 754.0, 0),
                ("12:34", nil, 1), // Expected to return nil as no fraction digits present
            ]
            for (s,i,fdc) in expected {
                formatter.fractionDigits = fdc
                XCTAssertEqual(formatter.timeInterval(from: s), i)
            }
        }
    }*/
}
