import Foundation

/// 把用户敲下的原始按键（raw）转换成引擎使用的"拼音字母序列 + 音节边界"。
///
/// - 全拼：字母原样保留；`'`（隔音符）记为强制音节边界。
/// - 小鹤双拼：每两个键还原为一个完整音节；末尾落单的一个键放进 `pending`，只用于预编辑显示。
struct InputConversion {
    /// 拼音字母（ASCII 小写）。
    var letters: [UInt8] = []
    /// 升序的强制边界：位置 p 表示 letters[p] 之前必有音节边界。
    var forced: [Int] = []
    /// rawEnd[k]：消耗了 k 个字母后，对应消耗的原始按键数。长度恒为 letters.count + 1。
    var rawEnd: [Int] = [0]
    /// 尚未构成完整音节的尾部按键（仅双拼），按原样显示。
    var pending: String = ""

    static let empty = InputConversion()

    static func make(raw: [UInt8], scheme: InputScheme) -> InputConversion {
        switch scheme {
        case .fullPinyin: return fullPinyin(raw)
        case .doublePinyinXiaohe: return doublePinyin(raw)
        }
    }

    private static func fullPinyin(_ raw: [UInt8]) -> InputConversion {
        var c = InputConversion()
        var forced: [Int] = []
        for (i, b) in raw.enumerated() {
            if b == 39 { // 隔音符 '
                if !c.letters.isEmpty, forced.last != c.letters.count {
                    forced.append(c.letters.count)
                }
                c.rawEnd[c.rawEnd.count - 1] = i + 1 // 隔音符随前一个字母一起被消耗
            } else {
                c.letters.append(b)
                c.rawEnd.append(i + 1)
            }
        }
        c.forced = forced.filter { $0 < c.letters.count }
        return c
    }

    private static func doublePinyin(_ raw: [UInt8]) -> InputConversion {
        var c = InputConversion()
        var i = 0
        while i < raw.count {
            if i + 1 >= raw.count {
                c.pending = String(UnicodeScalar(raw[i]))
                break
            }
            let k1 = Character(UnicodeScalar(raw[i]))
            let k2 = Character(UnicodeScalar(raw[i + 1]))
            if !c.letters.isEmpty { c.forced.append(c.letters.count) }
            if let syllable = DoublePinyinXiaohe.syllable(k1, k2) {
                for b in syllable.utf8 {
                    c.letters.append(b)
                    c.rawEnd.append(i + 2) // 音节中途不能拆开消耗，统一对齐到音节末尾
                }
            } else {
                // 无法还原：把两个键原样当字母，后续解码会把它们当作未识别字母处理
                c.letters.append(raw[i])
                c.rawEnd.append(i + 1)
                c.letters.append(raw[i + 1])
                c.rawEnd.append(i + 2)
            }
            i += 2
        }
        return c
    }
}

/// 小鹤双拼方案：声母键 + 韵母键 → 全拼音节。
enum DoublePinyinXiaohe {
    /// 非 "原样" 的声母键。
    private static let initialOverrides: [Character: String] = ["u": "sh", "i": "ch", "v": "zh"]
    private static let plainInitials: Set<Character> = Set("bpmfdtnlgkhjqxrzcsyw")

    /// 韵母键 → 候选韵母（按优先级，取第一个能拼成合法音节的）。
    private static let finals: [Character: [String]] = [
        "q": ["iu"], "w": ["ei"], "e": ["e"], "r": ["uan"], "t": ["ue", "ve"],
        "y": ["un"], "u": ["u"], "i": ["i"], "o": ["uo", "o"], "p": ["ie"],
        "a": ["a"], "s": ["ong", "iong"], "d": ["ai"], "f": ["en"], "g": ["eng"],
        "h": ["ang"], "j": ["an"], "k": ["uai", "ing"], "l": ["uang", "iang"],
        "z": ["ou"], "x": ["ia", "ua"], "c": ["ao"], "v": ["ui", "v"], "b": ["in"],
        "n": ["iao"], "m": ["ian"],
    ]

    /// 零声母音节的两键写法。
    private static let zeroInitial: [String: String] = [
        "aa": "a", "oo": "o", "ee": "e", "ai": "ai", "an": "an", "ao": "ao",
        "ei": "ei", "en": "en", "er": "er", "ou": "ou", "ah": "ang", "eg": "eng",
    ]

    static func syllable(_ k1: Character, _ k2: Character) -> String? {
        if k1 == "a" || k1 == "o" || k1 == "e" {
            return zeroInitial[String([k1, k2])]
        }
        let initial: String
        if let special = initialOverrides[k1] {
            initial = special
        } else if plainInitials.contains(k1) {
            initial = String(k1)
        } else {
            return nil
        }
        guard let candidates = finals[k2] else { return nil }
        for f in candidates {
            if let s = spell(initial: initial, final: f), Lexicon.shared.isValidSyllable(s) {
                return s
            }
        }
        return nil
    }

    /// 声母 + 韵母 → 正字法拼写（处理 y/w 与 j/q/x 后的 ü）。
    private static func spell(initial: String, final f: String) -> String? {
        switch initial {
        case "y":
            switch f {
            case "i", "in", "ing": return "y" + f
            case "iu": return "you"
            case "v": return "yu"
            case "ve": return "yue"
            case "u", "ue", "uan", "un": return "y" + f
            default:
                if f.hasPrefix("i") { return "y" + f.dropFirst() }
                return "y" + f
            }
        case "w":
            switch f {
            case "u": return "wu"
            case "ui": return "wei"
            case "un": return "wen"
            default:
                if f.hasPrefix("u") { return "w" + f.dropFirst() }
                return "w" + f
            }
        case "j", "q", "x":
            switch f {
            case "v": return initial + "u"
            case "ve": return initial + "ue"
            default: return initial + f
            }
        default:
            return initial + f
        }
    }
}
