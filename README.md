# TimeIntervalFormatter

The missing TimeIntervalFormatter for TimeInterval.

## Example

    let formatter = TimeIntervalFormatter()
    formatter.style = .mmssf
    formatter.fractionDigits = 2
    formatter.fractionSeparator = "´"
    let interval = TimeInterval(123.45)
    formatter.string(from: interval) // "02:03´45"
