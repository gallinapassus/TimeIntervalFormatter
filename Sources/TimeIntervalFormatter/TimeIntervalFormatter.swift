import Foundation

/// A formatter that converts between TimeIntervals and their textual representations.
public class TimeIntervalFormatter /* NOTE: Does not conform to Formatter */ {
    /// Available styles for TimeInterval formatting
    public enum Style : Codable {
        /// Use all available elements, days, hours, minutes, seconds, fractions of seconds
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case full
        /// Use minimum amount of elements to present the value completely (dynamically alters the included elements)
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case required
        /// Use days, hours, minutes, seconds, fractions of seconds (same as `full`)
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case dhhmmssf
        /// Use only hours, minutes, seconds, fractions of seconds
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case hhmmssf
        /// Use only minutes, seconds, fractions of seconds
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case mmssf
        /// Use only seconds and fractions of seconds
        ///
        /// Note: Fractions are controlled by `TimeIntervalFormatter.fractionDigits` property
        case ssf
    }
    
    /// Initialize TimeIntervalFormatter
    public init() {}
    
    /// Initialize TimeIntervalFormatter with specific style
    public init(_ style:TimeIntervalFormatter.Style) {
        self.style = style
    }
    /// Convert `String` to TimeInterval value (if possible).
    ///
    /// For successful conversion fractionDigits value and formatter symbols must match the expected input string symbols.
    public func timeInterval(from:String) -> TimeInterval? {
        var parse = from // copy
        do {
            // Common for all styles
            let multiplier = try _parseMultiplier(&parse)
            try _consumeSeparator(&parse, separator: secondsSeparator)
            let expectedFractionCount = Swift.max(0, Swift.min(fractionDigits, Self.maxFractionDigits))
            var fractions:TimeInterval = 0.0
            if expectedFractionCount > 0 {
                fractions = try TimeInterval(_parseNumber(&parse, count: expectedFractionCount, validRange: 0...999999)) / pow(10.0, TimeInterval(expectedFractionCount))
                try _consumeSeparator(&parse, separator: fractionSeparator)
            }
            let ss = try _parseNumber(&parse, count: 2, validRange: 0...59)
            
            var accumulated = TimeInterval(ss) + fractions
            // Are we expecting minutes?
            if style == .ssf || style == .required, parse.isEmpty {
                return multiplier * accumulated
            }
            if style == .mmssf || style == .hhmmssf || style == .dhhmmssf || style == .full || style == .required {
                try _consumeSeparator(&parse, separator: minutesSeparator)
                let mm = try _parseNumber(&parse, count: 2, validRange: 0...59)
                accumulated += TimeInterval(mm * 60)
                if style == .mmssf || style == .required, parse.isEmpty {
                    return multiplier * accumulated
                }
            }
            if style == .hhmmssf || style == .dhhmmssf || style == .full || style == .required {
                try _consumeSeparator(&parse, separator: hoursSeparator)
                let hh = try _parseNumber(&parse, count: 2, validRange: 0...23)
                accumulated += TimeInterval(hh * 3600)
                if style == .hhmmssf || style == .required, parse.isEmpty {
                    return multiplier * accumulated
                }
            }
            if style == .dhhmmssf || style == .full || style == .required {
                try _consumeSeparator(&parse, separator: daysSeparator)
                let d = try _parseNumber(&parse, count: parse.count, validRange: 0...Self.decade)
                accumulated += TimeInterval(d * 86400)
                if parse.isEmpty {
                    return multiplier * accumulated
                }
                else {
                    throw ParseFailure.fail
                }
            }
            throw ParseFailure.fail
        } catch {
            return nil
        }
    }
    /// Generate properly formatted string indicating overflow/underflow or nil value.
    private func _failed(symbol:String) -> String {
        let fracCount = Swift.min(Swift.max(0, fractionDigits), Self.maxFractionDigits)
        let fracs = String(repeating: symbol, count: fracCount)
        let fs = fracCount > 0 ? "\(fractionSeparator)\(fracs)" : ""
        switch style {
        case .full, .dhhmmssf, .required:
            return "\(symbol)\(daysSeparator)\(symbol)\(symbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsSeparator)"
        case .hhmmssf:
            return "\(symbol)\(symbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsSeparator)"
        case .mmssf:
            return "\(symbol)\(symbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsSeparator)"
        case .ssf:
            return "\(symbol)\(symbol)\(fs)\(secondsSeparator)"
        }
    }
    /// Genrates the formatted and styled string for the given value
    private func _getFormattedString(_ s:TimeIntervalFormatter.Style, value:TimeInterval) -> String {
        var stack:[String] = value < 0.0 ? [negativeSymbol] : (positiveSymbol.isEmpty ? [] : [positiveSymbol])

        let multiplier = pow(10.0, Double(fractionDigits))
        let roundedFraction = (((value - Double(Int(value))) * multiplier).rounded() / multiplier).magnitude
        let roundedFractionAsInt = Int(roundedFraction * multiplier)
        let formatString = "%0\(_fractionDigits)d%@"

        let integer:Int
        let formattedFractions:String
        if roundedFraction >= 1.0 {
            integer = Int(value.magnitude) + 1
            formattedFractions = String(format: formatString, 0, secondsSeparator)
        }
        else {
            integer = Int(value.magnitude)
            formattedFractions = String(format: formatString, roundedFractionAsInt, secondsSeparator)
        }

        let ddd:Int = integer / 86400
        let dt:Int = ddd * 86400
        let _h:Int = integer - dt
        let hh:Int = _h / 3600
        let ht:Int = hh * 3600
        let _m:Int = _h - ht
        let mm:Int = _m / 60
        let ss:Int = _m - (mm * 60)
        
        var overflow = false
        switch s {
        case .dhhmmssf, .full:
            if integer > Self.decade {
                let unit = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(overflowSymbol)\(daysSeparator)\(unit)\(hoursSeparator)\(unit)\(minutesSeparator)\(unit)\(secondsSeparator)"
                )
                overflow = true
            }
            else {
                stack.append(
                    String(format: "%d%@%02d%@%02d%@%02d",
                           ddd, daysSeparator,
                           hh, hoursSeparator,
                           mm, minutesSeparator,
                           ss)
                )
            }
        case .hhmmssf:
            if integer > 86399 {
                let unit = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(unit)\(hoursSeparator)\(unit)\(minutesSeparator)\(unit)\(secondsSeparator)"
                )
                overflow = true
            }
            else {
                stack.append(
                    String(format: "%02d%@%02d%@%02d",
                           hh, hoursSeparator,
                           mm, minutesSeparator,
                           ss)
                )
            }
        case .mmssf:
            if integer > 3599 {
                let unit = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(unit)\(minutesSeparator)\(unit)\(secondsSeparator)")
                overflow = true
            }
            else {
                stack.append(String(format: "%02d%@%02d", mm, minutesSeparator, ss))
            }
        case .ssf:
            if integer > 59 {
                stack.append(String(repeating: overflowSymbol, count: 2))
                overflow = true
            }
            else {
                stack.append(String(format: "%02d", integer))
            }
        case .required: fatalError() // .required is never used here
        }
        if (1...Self.maxFractionDigits).contains(fractionDigits) {
            if overflow {
                stack.append("\(fractionSeparator)\(String(repeating: overflowSymbol, count: fractionDigits))")
            }
            else {
                stack.append("\(fractionSeparator)\(formattedFractions)")
            }
        }
        return stack.joined()
    }
    /// Determines the final style to be used for the value
    private func _finalStyle(_ style:TimeIntervalFormatter.Style, _ timeInterval:TimeInterval) -> TimeIntervalFormatter.Style {
        let adjustedStyle:TimeIntervalFormatter.Style
        if style == .required {
            if timeInterval >= 86400 {
                adjustedStyle = .dhhmmssf
            }
            else if timeInterval >= 3600 {
                adjustedStyle = .hhmmssf
            }
            else if timeInterval >= 60 {
                adjustedStyle = .mmssf
            }
            else {
                adjustedStyle = .ssf
            }
        }
        else {
            adjustedStyle = style
        }
        return adjustedStyle
    }
    /// Convert TimeInterval value to a formatted `String`
    ///
    /// String presentation is a rounded representation of the TimeInterval value for the selected style.
    /// For rounding, formatter uses the rounded() method, which uses the .toNearestOrAwayFromZero
    /// rounding rule, where a value halfway between two integral values is rounded to the one with
    /// greater magnitude.
    ///
    /// A non-zero `fractionDigits` value will return best rounded approximation for the TimeInterval.
    ///
    /// Examples
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     formatter.style = .mmssf
    ///     let a = TimeInterval(123.51)
    ///     formatter.string(from: a) // "02:04"
    ///     let b = TimeInterval(59.51)
    ///     formatter.string(from: b) // "01:00"
    ///
    ///     let c = TimeInterval(-123.50)
    ///     formatter.string(from: c) // "-02:04"
    ///     let d = TimeInterval(-123.49)
    ///     formatter.string(from: c) // "-02:03"
    public func string(from: TimeInterval?) -> String {

        guard let from = from else {
            return _failed(symbol: nanSymbol)
        }
        guard Self.validRange.contains(from) else {
            return _failed(symbol: overflowSymbol)
        }

        let stack = _getFormattedString(_finalStyle(style, from), value: from)
        return stack
    }
    /// The time interval style of the receiver.
    public var style:TimeIntervalFormatter.Style = .required
    /// Number of fraction digits to show (up to 6 digits).
    ///
    /// Default value is `0` (=don't show fractions).
    public var fractionDigits:Int {
        set (value) {
            self._fractionDigits = value
        }
        get {
            return Swift.min(Swift.max(0, self._fractionDigits), Self.maxFractionDigits)
        }
    }
    private var _fractionDigits:Int = 0
    /// Use this symbol in-place of numbers when TimeInterval overflows the given style.
    ///
    /// Default symbol: `*`
    ///
    /// Example:
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     formatter.style = .mmssf
    ///     formatter.overflowSymbol = "~"
    ///     formatter.string(from: TimeInterval(3600)) // ~~:~~
    public var overflowSymbol:String    = "*"
    /// Use this symbol to indicate a negative time interval.
    ///
    /// Default symbol: `-`
    public var negativeSymbol:String    = "-"
    /// Use this symbol to indicate a positive time interval.
    ///
    /// Default symbol: `empty string`
    public var positiveSymbol:String    = ""
    /// Use this symbol to separate seconds from fractions of seconds.
    ///
    /// Default symbol: `.`
    ///
    /// Example:
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     formatter.style = .mmssf
    ///     formatter.fractionDigits = 2
    ///     formatter.fractionSeparator = "´"
    ///     formatter.string(from: TimeInterval(123.45)) // 02:03´45
    public var fractionSeparator:String = "."
    /// Use this symbol at the end of seconds (or fractions of seconds).
    ///
    /// Default symbol: `empty string`
    public var secondsSeparator:String  = ""
    /// Use this symbol to separate minutes from seconds.
    ///
    /// Default separator: `:`
    public var minutesSeparator:String  = ":"
    /// Use this symbol to separate hours from minutes.
    ///
    /// Default separator: `:`
    public var hoursSeparator:String    = ":"
    /// Use this symbol to separate days from hours.
    ///
    /// Default separator: `:`
    public var daysSeparator:String     = ":"
    /// Use this symbol to indicate that given time interval was not representable
    /// by this formatter (for example a nil value).
    ///
    /// Default symbol: `-`
    ///
    /// Example:
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     formatter.style = .full
    ///     formatter.string(from: nil) // -:--:--:--

    public var nanSymbol:String         = "-"
    /// Maximum number of fraction digits to show.
    private static let maxFractionDigits = 6
    /// Number of seconds in an imaginary decade (a sum of ten 365 day years).
    ///
    /// This implementation ignores leap years and other exceptions and
    /// assumes decade contains exactly 315360000 seconds.
    private static let decade:Int = 315360000 // 60 * 60 * 24 * 365 * 10
    /// TimeIntervalFormatter's valid range is limited to one decade.
    ///
    /// Any time intervals (positive or negative) reaching out beyond one decade will cause formatter to
    /// return overflow/underflow representation.
    private static let validRange = -TimeInterval(decade)...TimeInterval(decade)
}

fileprivate enum ParseFailure : Error { case fail }
// MARK: -
fileprivate extension TimeIntervalFormatter {
    private func _parseMultiplier(_ str:inout String) throws -> TimeInterval {
        switch (negativeSymbol.isEmpty, positiveSymbol.isEmpty) {
        case (true, true): // Expect numbers
            if let c = str.first, c.isNumber {
                return 1.0
            }
            else {
                throw ParseFailure.fail
            }
        case (false, true): // Expect 'negativeSymbol' or number
            if let r = str.range(of: negativeSymbol), r.lowerBound == str.startIndex {
                str = "\(str[r.upperBound...])"
                return -1.0
            }
            else if let c = str.first, c.isNumber {
                // Counter intuitive, but yes, this is positive
                return 1.0
            }
            else {
                throw ParseFailure.fail
            }
        case (true, false): // Expect 'positiveSymbol' or number
            if let r = str.range(of: positiveSymbol), r.lowerBound == str.startIndex {
                str = "\(str[r.upperBound...])"
                return 1.0
            }
            else if let c = str.first, c.isNumber {
                // Counter intuitive, but yes, this is negative
                return -1.0
            }
            else {
                throw ParseFailure.fail
            }
        case (false, false): // Expect 'negativeSymbol' or 'positiveSymbol'
            if let r = str.range(of: negativeSymbol) {
                str = "\(str[r.upperBound...])"
                return -1.0
            }
            else if let r = str.range(of: positiveSymbol) {
                str = "\(str[r.upperBound...])"
                return 1.0
            }
            else {
                throw ParseFailure.fail
            }
        }
    }
    private func _parseNumber(_ str:inout String, count:Int, validRange:ClosedRange<Int>) throws -> Int {
        guard let numberStart = str.index(str.endIndex, offsetBy: -count, limitedBy: str.startIndex),
              let numberPart = Int("\(str[numberStart...])", radix: 10),
              validRange.contains(numberPart) else {
            throw ParseFailure.fail
        }
        str = "\(str[..<numberStart])"
        return numberPart
    }
    // MARK: -
    private func _consumeSeparator(_ str:inout String, separator:String) throws {
        guard separator.isEmpty == false else {
            return
        }
        guard let separatorStart = str.index(str.endIndex, offsetBy: -separator.count, limitedBy: str.startIndex),
            str[separatorStart...] == separator else {
            throw ParseFailure.fail
        }
        str = "\(str[..<separatorStart])"
    }
}
