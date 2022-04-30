import Foundation

/// A formatter that converts between TimeIntervals and their textual representations.
public class TimeIntervalFormatter : Formatter, Codable {
    /// Available styles for TimeInterval formatting
    public enum Style : Codable, CaseIterable {
        /// Use all available elements, days, hours, minutes, seconds, fractions of seconds
        ///
        /// - Attention: Fractions of seconds are controlled by `TimeIntervalFormatter.fractionDigits` property
        case full
        /// Use minimum amount of elements to present the value completely (dynamically alters the included elements)
        ///
        /// - Attention: Fractions of seconds are controlled by `TimeIntervalFormatter.fractionDigits` property
        case required
        /// Use days, hours, minutes, seconds, fractions of seconds (same as `full`)
        ///
        /// - Attention: Fractions of seconds are controlled by `TimeIntervalFormatter.fractionDigits` property
        case dhhmmssf
        /// Use days, hours, minutes
        ///
        /// - Attention: Seconds and fractions of seconds are not available in this style,
        ///  regardless of the `TimeIntervalFormatter.fractionDigits` property's value.
        case dhhmm
        /// Use hours, minutes
        ///
        /// - Attention: Seconds and fractions of seconds are not available in this style,
        ///  regardless of the `TimeIntervalFormatter.fractionDigits` property's value.
        case hhmm
        /// Use only hours, minutes, seconds, fractions of seconds
        ///
        /// - Attention: Fractions of seconds are controlled by `TimeIntervalFormatter.fractionDigits` property
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
    override public init() {
        super.init()
    }

    /// Initialize TimeIntervalFormatter with specific style
    public init(_ style:TimeIntervalFormatter.Style) {
        self.style = style
        super.init()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /// Convert `String` to TimeInterval value (if possible).
    ///
    /// For successful conversion fractionDigits value and formatter symbols must match the
    /// expected input string symbols.
    ///
    /// Example
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     // default style is `.dhhmmssf`
    ///     formatter.timeInterval(from: "1:23:45:32") // Optional(45296.7)
    ///
    ///     formatter.style = .hhmmssf
    ///     formatter.hoursSeparator = "h "
    ///     formatter.minutesSeparator = "m "
    ///     formatter.secondsSeparator = "s"
    ///     formatter.fractionSeparator = "´"
    ///     formatter.fractionDigits = 1
    ///     formatter.timeInterval(from: "12h 34m 56´7s") // Optional(45296.7)
    ///
    /// - Attention: Parsing TimeInterval value with `.dhhmm` or `.hhmm` styles expects
    /// the `minutesSeparator`. Default `minutesSeparator` is `:` which leads to
    /// unintuitive format for the expected string (see example below).
    ///
    /// Example
    ///
    ///     let formatter = TimeIntervalFormatter()
    ///     formatter.style = .hhmm
    ///     formatter.timeInterval(from: "12:34") // nil
    ///     // above failed as the default minutesSeparator ":"
    ///     // was not present at the end
    ///
    ///     formatter.timeInterval(from: "12:34:") // Optional(45240.0)
    ///     // above succeeds as the default minutesSeparator
    ///     // was present at the end
    ///
    ///     formatter.minutesSeparator = "" // workaround
    ///     formatter.timeInterval(from: "12:34") // Optional(45240.0)
    
    public func timeInterval(from:String) -> TimeInterval? {
        var parse = from // copy
        do {
            // Common for all styles
            let multiplier = try _parseSign(&parse)

            // Special cases .hhmm and .dhhmm
            if style == .hhmm {
                try _consume(minutesSeparator, from: &parse)
                let mm = try _parseNumber(&parse, count: 2, validRange: 0...59)
                try _consume(hoursSeparator, from: &parse)
                let hh = try _parseNumber(&parse, count: 2, validRange: 0...23)
                return multiplier * TimeInterval(mm * 60 + hh * 3600)
            }
            else if style == .dhhmm {
                try _consume(minutesSeparator, from: &parse)
                let mm = try _parseNumber(&parse, count: 2, validRange: 0...59)
                try _consume(hoursSeparator, from: &parse)
                let hh = try _parseNumber(&parse, count: 2, validRange: 0...23)
                try _consume(daysSeparator, from: &parse)
                let d = try _parseNumber(&parse, count: parse.count, validRange: 0...Self.decade)
                return multiplier * TimeInterval(mm * 60 + hh * 3600 + d * 86400)
            }
            
            // Rest of the cases
            try _consume(secondsUnitSymbol, from: &parse)
            let expectedFractionCount = Swift.max(0, Swift.min(fractionDigits, Self.maxFractionDigits))
            var fractions:TimeInterval = 0.0
            if expectedFractionCount > 0 {
                fractions = try TimeInterval(_parseNumber(&parse, count: expectedFractionCount, validRange: 0...999999)) / pow(10.0, TimeInterval(expectedFractionCount))
                try _consume(fractionSeparator, from: &parse)
            }
            let ss = try _parseNumber(&parse, count: 2, validRange: 0...59)
            
            var accumulated = TimeInterval(ss) + fractions
            // Are we done yet?
            if style == .ssf || style == .required, parse.isEmpty {
                return multiplier * accumulated
            }
            if style == .mmssf || style == .hhmmssf || style == .dhhmmssf || style == .full || style == .required {
                try _consume(minutesSeparator, from: &parse)
                try _consume(minutesUnitSymbol, from: &parse)
                let mm = try _parseNumber(&parse, count: 2, validRange: 0...59)
                accumulated += TimeInterval(mm * 60)
                if style == .mmssf || style == .required, parse.isEmpty {
                    return multiplier * accumulated
                }
            }
            if style == .hhmmssf || style == .dhhmmssf || style == .full || style == .required {
                try _consume(hoursSeparator, from: &parse)
                try _consume(hoursUnitSymbol, from: &parse)
                let hh = try _parseNumber(&parse, count: 2, validRange: 0...23)
                accumulated += TimeInterval(hh * 3600)
                if style == .hhmmssf || style == .required, parse.isEmpty {
                    return multiplier * accumulated
                }
            }
            if style == .dhhmmssf || style == .full || style == .required {
                try _consume(daysSeparator, from: &parse)
                try _consume(daysUnitSymbol, from: &parse)
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
            return "\(symbol)\(daysUnitSymbol)\(daysSeparator)\(symbol)\(symbol)\(hoursUnitSymbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesUnitSymbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsUnitSymbol)"
        case .dhhmm:
            return "\(symbol)\(daysUnitSymbol)\(daysSeparator)\(symbol)\(symbol)\(hoursUnitSymbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesUnitSymbol)"
        case .hhmm:
            return "\(symbol)\(symbol)\(hoursUnitSymbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesUnitSymbol)"
        case .hhmmssf:
            return "\(symbol)\(symbol)\(hoursUnitSymbol)\(hoursSeparator)\(symbol)\(symbol)\(minutesUnitSymbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsUnitSymbol)"
        case .mmssf:
            return "\(symbol)\(symbol)\(minutesUnitSymbol)\(minutesSeparator)\(symbol)\(symbol)\(fs)\(secondsUnitSymbol)"
        case .ssf:
            return "\(symbol)\(symbol)\(fs)\(secondsUnitSymbol)"
        }
    }
    /// Genrates the formatted and styled string for the given value
    private func _getFormattedString(_ s:TimeIntervalFormatter.Style, value:TimeInterval) -> String {
        var stack:[String] = value < 0.0 ? [negativeTimeIntervalSymbol] : (positiveTimeIntervalSymbol.isEmpty ? [] : [positiveTimeIntervalSymbol])

        let multiplier = pow(10.0, Double(fractionDigits))
        let roundedFraction = (((value - Double(Int(value))) * multiplier).rounded() / multiplier).magnitude
        let roundedFractionAsInt = Int(roundedFraction * multiplier)
        let formatString = "%0\(_fractionDigits)d%@"

        let integer:Int
        let formattedFractions:String
        if roundedFraction >= 1.0 {
            integer = Int(value.magnitude) + 1
            formattedFractions = String(format: formatString, 0, secondsUnitSymbol)
        }
        else {
            integer = Int(value.magnitude)
            formattedFractions = String(format: formatString, roundedFractionAsInt, secondsUnitSymbol)
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
        case .dhhmmssf, .full, .dhhmm:
            if integer > Self.decade {
                let pair = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(overflowSymbol)\(daysUnitSymbol)\(daysSeparator)\(pair)\(hoursUnitSymbol)\(hoursSeparator)\(pair)\(minutesUnitSymbol)\(minutesSeparator)")
                overflow = true
                if s != .dhhmm {
                    stack.append("\(pair)\(secondsUnitSymbol)")
                }
            }
            else {
                stack.append(
                    String(format: "%d%@%@%02d%@%@%02d%@",
                           ddd, daysUnitSymbol, daysSeparator,
                           hh, hoursUnitSymbol, hoursSeparator,
                           mm, minutesUnitSymbol/*, minutesSeparator*/)
                )
                if s != .dhhmm {
                    stack.append(String(format: "%@%02d%@", minutesSeparator, ss, _emptyOrSecondsUnit))
                }
            }
        case .hhmmssf, .hhmm:
            if integer > 86399 {
                let pair = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(pair)\(hoursUnitSymbol)\(hoursSeparator)\(pair)\(minutesUnitSymbol)\(minutesSeparator)")
                if s != .hhmm {
                    stack.append( "\(pair)\(secondsUnitSymbol)")
                }
                overflow = true
            }
            else {
                stack.append(
                    String(format: "%02d%@%@%02d%@",
                           hh, hoursUnitSymbol, hoursSeparator,
                           mm, minutesUnitSymbol/*, minutesSeparator*/)
                )
                if s != .hhmm {
                    stack.append(String(format: "%@%02d%@", minutesSeparator, ss, _emptyOrSecondsUnit))
                }
            }
        case .mmssf:
            if integer > 3599 {
                let pair = "\(overflowSymbol)\(overflowSymbol)"
                stack.append( "\(pair)\(minutesSeparator)\(pair)\(secondsUnitSymbol)")
                overflow = true
            }
            else {
                stack.append(String(format: "%02d%@%@%02d%@",
                                    mm, minutesUnitSymbol, minutesSeparator,
                                    ss, _emptyOrSecondsUnit))
            }
        case .ssf:
            if integer > 59 {
                stack.append(String(repeating: overflowSymbol, count: 2))
                overflow = true
            }
            else {
                stack.append(String(format: "%02d%@", integer, secondsUnitSymbol))
            }
        case .required: fatalError() // .required is never used here
        }
        if _fractionDigits > 0, style != .dhhmm, style != .hhmm {
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
            if timeInterval.magnitude >= 86400 {
                adjustedStyle = .dhhmmssf
            }
            else if timeInterval.magnitude >= 3600 {
                adjustedStyle = .hhmmssf
            }
            else if timeInterval.magnitude >= 60 {
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
    /// Default value is `0` (=don't show fractions of seconds).
    ///
    /// - Important: `fractionDigits` property will return `0` if formatter style doesn't have a seconds
    ///  component present (like for example `.dhhmm` and `.hhmm` styles).
    public var fractionDigits:Int {
        set (value) {
            self._fractionDigits = value
        }
        get {
            switch style {
            case .dhhmm, .hhmm: return 0
            default: return Swift.min(Swift.max(0, self._fractionDigits), Self.maxFractionDigits)

            }
        }
    }
    private var _fractionDigits:Int = 0
    private var _emptyOrSecondsUnit:String {
        _fractionDigits > 0 ? "" : "\(secondsUnitSymbol)"
    }
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
    public var overflowSymbol:String = "*"
    /// Use this symbol to indicate a negative time interval.
    ///
    /// Default symbol: `-`
    public var negativeTimeIntervalSymbol:String = "-"
    /// Use this symbol to indicate a positive time interval.
    ///
    /// Default symbol: `empty string`
    public var positiveTimeIntervalSymbol:String = ""
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
    /// Unit symbol for seconds.
    ///
    /// Default symbol: `empty string`
    public var secondsUnitSymbol:String  = ""
    /// Use this symbol to separate minutes from seconds.
    ///
    /// Default separator: `:`
    public var minutesSeparator:String  = ":"
    /// Unit symbol for minutes.
    ///
    /// Default symbol: `empty string`
    public var minutesUnitSymbol:String  = ""
    /// Use this symbol to separate hours from minutes.
    ///
    /// Default separator: `:`
    public var hoursSeparator:String    = ":"
    /// Unit symbol for hours.
    ///
    /// Default symbol: `empty string`
    public var hoursUnitSymbol:String  = ""
    /// Use this symbol to separate days from hours.
    ///
    /// Default separator: `:`
    public var daysSeparator:String     = ":"
    /// Unit symbol for days.
    ///
    /// Default symbol: `empty string`
    public var daysUnitSymbol:String  = ""
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

    public var nanSymbol:String = "-"
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
    private func _parseSign(_ str:inout String) throws -> TimeInterval {
        switch (negativeTimeIntervalSymbol.isEmpty, positiveTimeIntervalSymbol.isEmpty) {
        case (true, true): // Expect numbers
            if let c = str.first, c.isNumber {
                return 1.0
            }
            else {
                throw ParseFailure.fail
            }
        case (false, true): // Expect 'negativeSymbol' or number
            if let r = str.range(of: negativeTimeIntervalSymbol), r.lowerBound == str.startIndex {
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
            if let r = str.range(of: positiveTimeIntervalSymbol), r.lowerBound == str.startIndex {
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
            if let r = str.range(of: negativeTimeIntervalSymbol) {
                str = "\(str[r.upperBound...])"
                return -1.0
            }
            else if let r = str.range(of: positiveTimeIntervalSymbol) {
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
    private func _consume(_ string:String, from target:inout String) throws {
        guard string.isEmpty == false else {
            return
        }
        guard let separatorStart = target.index(target.endIndex, offsetBy: -string.count, limitedBy: target.startIndex),
            target[separatorStart...] == string else {
            throw ParseFailure.fail
        }
        target = "\(target[..<separatorStart])"
    }
}
