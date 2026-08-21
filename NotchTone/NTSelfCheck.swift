import Foundation
import SwiftUI

enum NTCheckTheme: String, CaseIterable, Identifiable {
    case sleep
    case concentration
    case mood
    case social
    case coping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .concentration: return "Concentration"
        case .mood: return "Mood"
        case .social: return "Everyday life"
        case .coping: return "Coping"
        }
    }

    var tint: Color {
        switch self {
        case .sleep: return NTTheme.seriesMask
        case .concentration: return NTTheme.seriesPitch
        case .mood: return NTTheme.seriesLoud
        case .social: return NTTheme.indigo
        case .coping: return NTTheme.seriesScore
        }
    }
}

struct NTCheckItem: Identifiable {
    let id: Int
    let theme: NTCheckTheme
    let text: String
    /// True when a high answer is the *good* outcome, so it is reverse-scored.
    let reversed: Bool
}

struct NTCheckBand {
    let lower: Int
    let upper: Int
    let title: String
    let summary: String
    let suggestion: String
    let tint: Color
}

/// Notch Tone's own twelve-item self-check. It is written from scratch for this app.
/// It is deliberately NOT any published questionnaire, it is not a clinical score, and
/// the app never presents it as one — it exists so a person can watch their own number
/// move over months and bring that observation to a professional if they want to.
enum NTSelfCheck {

    /// One scale for all twelve items, always in the same order. Items where a high
    /// answer is the good outcome are reverse-scored instead of relabelled, so the
    /// person answering never has to re-learn which end is which.
    static let answerLabels: [String] = ["Never", "Rarely", "Sometimes", "Often", "Almost always"]

    static let maximumScore = 48

    static let items: [NTCheckItem] = [
        NTCheckItem(id: 0, theme: .sleep,
                    text: "Over the past two weeks, the sound made it harder to fall asleep.",
                    reversed: false),
        NTCheckItem(id: 1, theme: .sleep,
                    text: "I woke during the night and the sound was the first thing I noticed.",
                    reversed: false),
        NTCheckItem(id: 2, theme: .concentration,
                    text: "The sound pulled my attention away from reading, work or study.",
                    reversed: false),
        NTCheckItem(id: 3, theme: .concentration,
                    text: "I lost the thread of a conversation because part of my attention was on the sound.",
                    reversed: false),
        NTCheckItem(id: 4, theme: .mood,
                    text: "Noticing the sound left me feeling irritable or on edge.",
                    reversed: false),
        NTCheckItem(id: 5, theme: .mood,
                    text: "I found myself worrying about what the sound might mean for my future.",
                    reversed: false),
        NTCheckItem(id: 6, theme: .mood,
                    text: "The sound made an otherwise ordinary day feel worse.",
                    reversed: false),
        NTCheckItem(id: 7, theme: .social,
                    text: "I avoided a place, an activity or a person because of the sound.",
                    reversed: false),
        NTCheckItem(id: 8, theme: .social,
                    text: "I needed to explain the sound to someone in order to be understood.",
                    reversed: false),
        NTCheckItem(id: 9, theme: .coping,
                    text: "When I noticed the sound, I had a way of settling myself that worked.",
                    reversed: true),
        NTCheckItem(id: 10, theme: .coping,
                    text: "There were long stretches of the day when I did not think about the sound at all.",
                    reversed: true),
        NTCheckItem(id: 11, theme: .coping,
                    text: "I felt able to get on with the things that matter to me despite the sound.",
                    reversed: true)
    ]

    /// Convert a raw tap (0-4 on the shown scale) into the scored value.
    static func score(itemIndex: Int, rawAnswer: Int) -> Int {
        let a = max(0, min(4, rawAnswer))
        guard itemIndex >= 0 && itemIndex < items.count else { return a }
        return items[itemIndex].reversed ? 4 - a : a
    }

    static func labels(for itemIndex: Int) -> [String] {
        answerLabels
    }

    static let bands: [NTCheckBand] = [
        NTCheckBand(lower: 0, upper: 9,
                    title: "Little day-to-day impact",
                    summary: "On these answers the sound is present but is not taking much from your days. That is a good place to be, and it is worth noticing what is already working.",
                    suggestion: "Keep the habits that are helping. Repeating this self-check every few weeks makes a change easier to spot early.",
                    tint: NTTheme.seriesMask),
        NTCheckBand(lower: 10, upper: 20,
                    title: "Some impact, in specific places",
                    summary: "The sound is reaching into particular corners of your life — often sleep, or quiet concentration — while much of the day is unaffected.",
                    suggestion: "Look at the theme bars below. If one is carrying most of the score, that is the corner worth working on first.",
                    tint: NTTheme.seriesPitch),
        NTCheckBand(lower: 21, upper: 32,
                    title: "Broad impact across the day",
                    summary: "These answers describe something that shows up across sleep, attention and mood rather than in one place only.",
                    suggestion: "This is the range in which many people find it useful to talk to an audiologist or their doctor about what support is available. Bringing this history with you can make that conversation more concrete.",
                    tint: NTTheme.seriesScore),
        NTCheckBand(lower: 33, upper: 48,
                    title: "Heavy impact",
                    summary: "These answers describe a sound that is taking a great deal from your days. Living with that is genuinely hard, and it is not something you have to work out alone.",
                    suggestion: "Please arrange to see an audiologist or your doctor. If you are also having thoughts of harming yourself, contact your local emergency number or a crisis line today — that is more urgent than anything in this app.",
                    tint: NTTheme.amber)
    ]

    static func band(for total: Int) -> NTCheckBand {
        let t = max(0, min(maximumScore, total))
        for b in bands where t >= b.lower && t <= b.upper { return b }
        return bands[0]
    }

    static func themeScore(_ record: NTSelfCheckRecord, theme: NTCheckTheme) -> Int {
        var sum = 0
        for item in items where item.theme == theme {
            if item.id < record.answers.count { sum += record.answers[item.id] }
        }
        return sum
    }

    static func themeMaximum(_ theme: NTCheckTheme) -> Int {
        items.filter { $0.theme == theme }.count * 4
    }
}
