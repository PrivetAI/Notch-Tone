import Foundation
import SwiftUI

// The Learn library. Everything here is authored for this app, written in plain language,
// deliberately cautious about what is and is not established, and free of product claims.
// Nothing in this file tells anyone what their symptoms mean or what they should take.

enum NTLearnBlock {
    case paragraph(String)
    case bullets([String])
    case callout(String)
    case pairs([NTPair])
    case exposureTable
}

struct NTPair {
    let left: String
    let right: String
}

struct NTLearnGroup: Identifiable {
    let id: String
    let title: String
    let caption: String
}

struct NTLearnCard: Identifiable {
    let id: String
    let groupID: String
    let title: String
    let summary: String
    let blocks: [NTLearnBlock]
    var urgent: Bool = false
    var minutes: Int = 2
}

enum NTLearn {

    static let groups: [NTLearnGroup] = [
        NTLearnGroup(id: "basics", title: "What tinnitus is",
                     caption: "The plainest available description of the sound and where it seems to come from."),
        NTLearnGroup(id: "urgent", title: "When to seek care promptly",
                     caption: "The short list of patterns that deserve a professional's attention soon rather than eventually."),
        NTLearnGroup(id: "attention", title: "Attention and habituation",
                     caption: "Why the same sound can be unbearable one month and unremarkable the next."),
        NTLearnGroup(id: "sound", title: "Sound approaches",
                     caption: "What people mean by sound therapy, and where notched sound fits into it."),
        NTLearnGroup(id: "masking", title: "Masking and partial masking",
                     caption: "Two different goals that call for two different levels."),
        NTLearnGroup(id: "sleep", title: "Sleep",
                     caption: "The hours most people find hardest, and what tends to help."),
        NTLearnGroup(id: "protect", title: "Protecting your hearing",
                     caption: "Sound levels, safe durations, and the habits that matter most."),
        NTLearnGroup(id: "relax", title: "Relaxation and breathing",
                     caption: "Short, concrete exercises you can do without any equipment."),
        NTLearnGroup(id: "clinic", title: "Seeing an audiologist",
                     caption: "What an appointment actually involves, and how to prepare for one."),
        NTLearnGroup(id: "devices", title: "Hearing aids and devices",
                     caption: "How amplification and combination devices relate to tinnitus."),
        NTLearnGroup(id: "myths", title: "Common myths",
                     caption: "Widespread claims that do not hold up, and what is closer to the truth."),
        NTLearnGroup(id: "evidence", title: "What the evidence supports",
                     caption: "An honest account of where the research is strong, thin, or absent.")
    ]

    static func group(_ id: String) -> NTLearnGroup? {
        groups.first(where: { $0.id == id })
    }

    static func cards(in groupID: String) -> [NTLearnCard] {
        all.filter { $0.groupID == groupID }
    }

    static var urgentCard: NTLearnCard? {
        all.first(where: { $0.id == "urgent-signs" })
    }

    // MARK: - The library

    static let all: [NTLearnCard] = [

        // MARK: Basics
        NTLearnCard(id: "basics-what", groupID: "basics",
                    title: "Hearing a sound with no source",
                    summary: "A working definition, and how common it is.",
                    blocks: [
                        .paragraph("Tinnitus is the experience of hearing a sound — a ring, a hiss, a buzz, a whistle, a cricket-like chirp, sometimes a tone that seems to sit inside the head rather than in either ear — when nothing outside is making it. It is not imaginary. The hearing system really is producing activity that the brain interprets as sound."),
                        .paragraph("Surveys in many countries put the share of adults who notice it at least sometimes somewhere in the region of one in ten to one in seven, with a much smaller group describing it as burdensome. Estimates vary because researchers ask the question differently, so treat any single number you read with a little caution."),
                        .callout("This app is a self-management and sound-generation tool. It does not diagnose anything, and nothing in this library is medical advice.")
                    ], minutes: 2),

        NTLearnCard(id: "basics-mechanisms", groupID: "basics",
                    title: "The mechanisms people talk about",
                    summary: "Several overlapping explanations, none of them complete.",
                    blocks: [
                        .paragraph("There is no single agreed mechanism. The explanations that come up most often in the research literature overlap rather than compete:"),
                        .bullets([
                            "Reduced input. When part of the cochlea sends less signal — from noise exposure, age, or an ear condition — central auditory pathways appear to increase their own gain, and that raised background activity can be heard as sound.",
                            "Reorganised tuning. Neurons that lost their usual input may begin responding to neighbouring frequencies, which is one reason a matched pitch often lands near a region of reduced hearing.",
                            "Attention and salience networks. Brain areas concerned with threat detection and attention are consistently involved, which fits the everyday observation that stress makes tinnitus louder without changing the ear at all.",
                            "Somatic input. In many people, clenching the jaw, pressing on the neck, or moving the head changes the sound, pointing to connections between the auditory pathway and nearby sensory systems."
                        ]),
                        .paragraph("A useful way to hold all of this: the ear may start the process, but what determines how much it intrudes is largely what happens further up.")
                    ], minutes: 3),

        NTLearnCard(id: "basics-kinds", groupID: "basics",
                    title: "Ways people describe the sound",
                    summary: "Tonal, noise-like, pulsatile, and why the difference matters.",
                    blocks: [
                        .paragraph("Descriptions cluster into a few families. A tonal tinnitus sounds like a single pitch, often high, and is the kind the pitch-matching exercise in this app is best suited to. A noise-like tinnitus sounds like hiss, static or escaping steam and has no single pitch, so matching it gives a broad region rather than a number."),
                        .paragraph("Pulsatile tinnitus beats in time with the heart. It belongs in a different category because it can have a physical, sometimes treatable, source in blood flow near the ear. If yours pulses in time with your pulse, that is worth raising with a doctor rather than managing on your own."),
                        .paragraph("Some people hear more than one sound, or a sound that changes character across the day. That is common and does not mean anything is going wrong.")
                    ], minutes: 2),

        NTLearnCard(id: "basics-fluctuation", groupID: "basics",
                    title: "Why it changes from day to day",
                    summary: "Fluctuation is the norm, not a sign of deterioration.",
                    blocks: [
                        .paragraph("Almost everyone reports good days and bad days. Sleep, stress, a noisy environment, illness, caffeine and alcohol are the factors people mention most often, though which ones matter differs enormously between individuals — which is exactly why this app lets you log them and look at your own pattern rather than handing you a generic list of rules."),
                        .paragraph("A bad week is not evidence that things are getting worse. Over months, most people's ratings drift downward even when the sound itself is unchanged, because the amount of attention it commands falls."),
                        .callout("A rating that has climbed steadily over several months, or a sudden change in one ear, is different from ordinary fluctuation and is worth a professional opinion.")
                    ], minutes: 2),

        // MARK: Urgent
        NTLearnCard(id: "urgent-signs", groupID: "urgent",
                    title: "See someone promptly if any of these apply",
                    summary: "The short list. Read it once, properly.",
                    blocks: [
                        .paragraph("Most tinnitus is not urgent. These patterns are the exceptions, and they are the reason this card sits near the top of the library rather than buried at the end."),
                        .bullets([
                            "Sudden onset. Tinnitus that appeared abruptly, especially over hours or a day, and especially alongside a drop in hearing. Sudden hearing loss is generally treated as time-critical — days matter — so contact a doctor the same day rather than waiting to see whether it settles.",
                            "One ear only. Tinnitus clearly confined to one ear, or markedly worse on one side, deserves examination.",
                            "Pulsatile. A sound that beats in time with your heartbeat, or a whooshing that matches your pulse.",
                            "With hearing loss. Any new or worsening difficulty hearing, in either ear.",
                            "With dizziness or vertigo. Spinning, unsteadiness, or a feeling of the room moving.",
                            "With neurological symptoms. Facial weakness or numbness, severe headache, visual change, or difficulty speaking — these warrant urgent assessment.",
                            "After a head or ear injury, or after any sudden very loud exposure such as an explosion or a gunshot.",
                            "With ear pain or discharge, or a persistent feeling of blockage."
                        ]),
                        .callout("If your mood has reached the point where you are having thoughts of harming yourself, contact your local emergency number or a crisis line today. That is more important than anything else in this app."),
                        .paragraph("None of this is a diagnosis, and none of it means something is seriously wrong. It means a qualified person should look, sooner rather than later.")
                    ], urgent: true, minutes: 3),

        NTLearnCard(id: "urgent-how", groupID: "urgent",
                    title: "How to ask for an appointment quickly",
                    summary: "The words that get an appointment moved forward.",
                    blocks: [
                        .paragraph("Reception staff triage by what you say first. If any of the urgent patterns apply, lead with them in one sentence: for example, \"my hearing dropped suddenly in my right ear three days ago and I now have ringing in that ear.\" That is far more likely to get you seen quickly than \"I have tinnitus.\""),
                        .bullets([
                            "State when it started and whether it was sudden.",
                            "State which ear, or say clearly that it is both.",
                            "Mention hearing change, dizziness or pulsing explicitly if present.",
                            "Say if there was a loud exposure, an injury, or a new medication."
                        ]),
                        .paragraph("If you are told the wait is long and any urgent feature applies, it is reasonable to ask directly whether it should be seen sooner given that feature.")
                    ], urgent: true, minutes: 2),

        // MARK: Attention
        NTLearnCard(id: "attention-habituation", groupID: "attention",
                    title: "What habituation actually means",
                    summary: "The sound stops being news before it stops being audible.",
                    blocks: [
                        .paragraph("Habituation is the ordinary process by which a nervous system stops responding to a signal that carries no new information. You are habituated to the feeling of your clothes, the hum of a refrigerator, the sound of your own breathing. None of those got quieter. They stopped being flagged."),
                        .paragraph("Applied to tinnitus, habituation has two parts that can move independently. Habituation of reaction comes first: the sound stops producing a jolt of alarm. Habituation of perception follows: you notice it less often, and eventually there are whole hours you did not think about it."),
                        .paragraph("This is why an approach can be working even though the sound is unchanged. The measurement that improves is how much of your day it takes, and that is precisely what the self-check and diary in this app track.")
                    ], minutes: 3),

        NTLearnCard(id: "attention-monitoring", groupID: "attention",
                    title: "The monitoring trap",
                    summary: "Checking whether it is still there keeps it in the foreground.",
                    blocks: [
                        .paragraph("A very common pattern: you notice the sound, then check whether it is louder than yesterday, then check again an hour later. Each check is a small act of attention that keeps the signal marked as important, which is the opposite of what habituation needs."),
                        .paragraph("This is not a character flaw — it is what any sensible nervous system does with a signal it has classified as a possible threat. The way out is usually not to try to stop noticing, which rarely works, but to reduce the number of deliberate checks."),
                        .bullets([
                            "Pick one moment a day for a rating, and let the rest of the day be unrated. The diary in this app is built around a single daily entry for exactly this reason.",
                            "When you catch yourself checking, name it silently — \"checking\" — and return to what you were doing, without arguing with yourself about it.",
                            "Resist testing the sound in silence to see how bad it is today. That test is almost always misleading and almost always unpleasant."
                        ])
                    ], minutes: 3),

        NTLearnCard(id: "attention-silence", groupID: "attention",
                    title: "Why silence is uncomfortable",
                    summary: "Contrast, not volume, is what makes it stand out.",
                    blocks: [
                        .paragraph("In a very quiet room there is nothing else for the auditory system to work on, so the internal signal has the whole stage. The sound has not changed; the contrast has. This is why the same tinnitus can be inaudible on a busy street and overwhelming at three in the morning."),
                        .paragraph("Adding a low level of sound to a quiet environment reduces that contrast. Note that reducing contrast does not require covering the sound — a quiet bed of noise that leaves your tinnitus faintly audible often feels better than a loud one that buries it, and it is easier on your ears.")
                    ], minutes: 2),

        // MARK: Sound approaches
        NTLearnCard(id: "sound-what", groupID: "sound",
                    title: "What people mean by sound therapy",
                    summary: "A family of approaches, not a single technique.",
                    blocks: [
                        .paragraph("\"Sound therapy\" is an umbrella term covering anything from leaving a fan on at night to structured programmes delivered by an audiologist alongside counselling. What the approaches share is the use of external sound to change the relationship between you and the internal one."),
                        .paragraph("They differ in intent. Some aim to reduce the contrast with silence. Some aim to give attention somewhere else to go. Some aim to make the sound less alarming by pairing it with a relaxed state. Some aim at the auditory system's tuning itself, which is where notched sound belongs."),
                        .callout("Sound approaches are generally described as ways of managing the experience. Notch Tone makes no claim to remove tinnitus, and you should be sceptical of anything that does.")
                    ], minutes: 3),

        NTLearnCard(id: "sound-notched", groupID: "sound",
                    title: "What notched sound is meant to do",
                    summary: "The idea behind removing a band rather than adding one.",
                    blocks: [
                        .paragraph("Notched sound is broadband noise or music with a band of frequencies removed around the tinnitus pitch. The reasoning draws on lateral inhibition: neurons tuned to a given frequency are inhibited by activity in neighbouring ones. Feeding energy to the neighbours of the tinnitus region, while starving the region itself, is intended to increase the inhibition arriving at it."),
                        .paragraph("Notch Tone builds its notch from four cascaded band-reject filter sections centred on your matched frequency, with a selectable width of one half, one, or one and a half octaves. The spectrum drawn on the Sound tab is computed from those actual filter coefficients, so what you see is the response you are hearing."),
                        .callout("The evidence for notched sound is promising but not settled: studies are mostly small, effects are modest, and results are inconsistent between groups. It is offered here as something reasonable to try, not as an established remedy.")
                    ], minutes: 3),

        NTLearnCard(id: "sound-width", groupID: "sound",
                    title: "Choosing a notch width",
                    summary: "Half, one, or one and a half octaves.",
                    blocks: [
                        .paragraph("A wider notch is more forgiving of an imprecise pitch match, which matters because self-matching on a phone is inherently approximate. A narrower notch keeps more of the sound but demands that your matched frequency actually be close."),
                        .pairs([
                            NTPair(left: "1 1/2 octaves", right: "Most forgiving. A good default when your match is new or you are unsure of it."),
                            NTPair(left: "1 octave", right: "The width most descriptions of the technique assume. A reasonable middle."),
                            NTPair(left: "1/2 octave", right: "Tightest gap, brightest result. Worth trying once your match has repeated consistently.")
                        ]),
                        .paragraph("If the notched sound feels like it is not covering anything, that is expected — notching is not masking, and a notch centred correctly should leave your tinnitus audible.")
                    ], minutes: 2),

        NTLearnCard(id: "sound-duration", groupID: "sound",
                    title: "How long and how often",
                    summary: "Comfort first; hours matter less than consistency.",
                    blocks: [
                        .paragraph("There is no established schedule. Published protocols for sound approaches vary from an hour a day to most of the waking day, and the honest summary is that nobody knows the optimum. What is consistent across accounts is that comfort matters more than duration, and that consistency over weeks matters more than intensity over days."),
                        .bullets([
                            "Set the level so the sound is comfortably present, never so it competes with your tinnitus for prominence.",
                            "Use the sleep timer rather than leaving sound running indefinitely, so your ears get quiet periods.",
                            "Give any configuration several weeks before judging it. Day-to-day fluctuation will otherwise drown out any real effect.",
                            "Log what you used. The session log in the Diary tab pairs listening with that day's ratings."
                        ])
                    ], minutes: 2),

        // MARK: Masking
        NTLearnCard(id: "masking-vs", groupID: "masking",
                    title: "Masking versus partial masking",
                    summary: "Cover it completely, or leave it just audible?",
                    blocks: [
                        .paragraph("Complete masking means raising external sound until the tinnitus is inaudible. It brings immediate relief, and that relief is real. Its drawbacks are that it requires a higher level, that the tinnitus is often noticeable again the moment the sound stops, and that nothing has been learned in the meantime."),
                        .paragraph("Partial masking means setting the level so both sounds are present — the external sound is clearly there, your tinnitus is still faintly audible, and neither dominates. This is the level most structured programmes aim for, because the auditory system is being given something to work on without the internal signal being erased."),
                        .callout("If you are using this app at night mainly to get to sleep, complete masking at a low level is a perfectly reasonable choice. The two goals are not in competition.")
                    ], minutes: 3),

        NTLearnCard(id: "masking-mml", groupID: "masking",
                    title: "What a minimum masking level tells you",
                    summary: "The quietest noise that just covers it.",
                    blocks: [
                        .paragraph("The minimum masking level is the lowest level of noise at which your tinnitus stops being audible. Clinically it is measured with calibrated equipment; the exercise in this app is a self-matching version that produces a number in the app's own relative units, useful only for comparison with your own earlier attempts."),
                        .paragraph("A low value means a small amount of sound covers it, which is generally good news for how easy your tinnitus will be to manage with sound. A high value, or being unable to cover it at a comfortable level, is also useful information — it suggests sound approaches may work better for you as partial masking or as distraction than as cover."),
                        .callout("Never raise the level past comfortable in order to reach a number. Recording \"not covered at a comfortable level\" is a valid and useful result, and the app offers it as a button.")
                    ], minutes: 2),

        NTLearnCard(id: "masking-residual", groupID: "masking",
                    title: "Residual inhibition",
                    summary: "The quiet minute some people notice after sound stops.",
                    blocks: [
                        .paragraph("Some people find that for seconds to a few minutes after a masking sound stops, their tinnitus is quieter than usual or briefly gone. This is called residual inhibition. It is a well-documented observation and it is genuinely interesting, because it shows the sound is not fixed."),
                        .paragraph("It is not, however, a treatment: the effect is short, it does not occur for everyone, and chasing it by using louder sound is a poor trade. If you notice it, note it as a curiosity and as evidence that your auditory system is more flexible than it feels.")
                    ], minutes: 2),

        // MARK: Sleep
        NTLearnCard(id: "sleep-why", groupID: "sleep",
                    title: "Why nights are harder",
                    summary: "Quiet, darkness and nothing else to attend to.",
                    blocks: [
                        .paragraph("Three things line up at bedtime: the room is at its quietest, there is nothing else asking for attention, and if sleep does not come quickly there is time to think about why. Each of those raises the prominence of an internal sound without changing it at all."),
                        .paragraph("Sleep loss then feeds back — most people rate their tinnitus worse after a poor night, and a worse rating makes the next night harder to approach calmly. Breaking into that loop anywhere tends to help, which is why sleep is often the first thing worth working on.")
                    ], minutes: 2),

        NTLearnCard(id: "sleep-hygiene", groupID: "sleep",
                    title: "A practical bedtime routine",
                    summary: "Ordinary sleep habits, adjusted for tinnitus.",
                    blocks: [
                        .bullets([
                            "Keep the wake time fixed, even after a bad night. A consistent wake time does more for sleep than a consistent bedtime.",
                            "Give yourself a wind-down of at least half an hour with dim light and no screens close to the face.",
                            "Use a low, unchanging sound bed rather than silence — quiet enough that it does not command attention, present enough to reduce the contrast.",
                            "Set a timer rather than leaving sound on all night, so your ears have quiet hours. Ninety minutes covers most people's sleep onset.",
                            "If you are awake and frustrated after about twenty minutes, get up, sit somewhere dim, and go back when sleepy. Lying in bed being annoyed teaches the bed to mean being annoyed.",
                            "Keep caffeine to the first half of the day and be honest about alcohol: it shortens sleep onset and worsens the second half of the night."
                        ]),
                        .callout("Persistent insomnia has its own effective approaches, and cognitive behavioural therapy for insomnia is well supported. If sleep is the main problem, it is worth asking about that specifically.")
                    ], minutes: 3),

        NTLearnCard(id: "sleep-partner", groupID: "sleep",
                    title: "Sharing a bedroom",
                    summary: "Making a sound bed workable for two people.",
                    blocks: [
                        .paragraph("A sound bed that helps one person can keep another awake. A few things that usually resolve it: choose brown or low-passed noise rather than bright hiss, since low-frequency sound is less intrusive to a sleeping partner; place the phone on your side of the bed rather than between you; and set the level lower than feels ideal at first, because the level that feels right while awake is usually louder than the level you need once asleep."),
                        .paragraph("If a shared bed cannot be made to work, a single sleep-safe earphone at a very low level is an option worth discussing with an audiologist rather than improvising, particularly if you have any hearing loss.")
                    ], minutes: 2),

        // MARK: Protect
        NTLearnCard(id: "protect-levels", groupID: "protect",
                    title: "Sound levels and safe durations",
                    summary: "A reference table for common situations.",
                    blocks: [
                        .paragraph("Risk to hearing comes from a combination of level and time. As a rule of thumb widely used in occupational guidance, each increase of three decibels roughly halves the time you can safely be exposed. The figures below are commonly cited approximations for orientation, not a personal safety instruction — actual levels vary enormously with distance and setting."),
                        .exposureTable,
                        .callout("If you have to raise your voice to be heard by someone an arm's length away, the environment is loud enough to be worth protecting against.")
                    ], minutes: 3),

        NTLearnCard(id: "protect-plugs", groupID: "protect",
                    title: "Choosing and using ear protection",
                    summary: "Fit matters more than the number on the packet.",
                    blocks: [
                        .paragraph("Foam plugs are cheap and effective, but only when rolled thin and inserted deeply enough to sit inside the canal rather than perched at the entrance. A badly fitted plug can give a fraction of its rated attenuation."),
                        .bullets([
                            "Roll a foam plug tightly, pull the ear gently up and back, insert, and hold for twenty seconds while it expands.",
                            "Musicians' filters attenuate more evenly across frequencies, so music and speech stay clear rather than muffled. They cost more and are worth it if you go to concerts regularly.",
                            "Earmuffs are easier to get right than plugs and are better for intermittent use, such as power tools.",
                            "Carry a pair. The protection you have with you is the only kind that works."
                        ])
                    ], minutes: 2),

        NTLearnCard(id: "protect-overprotect", groupID: "protect",
                    title: "The other mistake: over-protection",
                    summary: "Wearing plugs in ordinary rooms can backfire.",
                    blocks: [
                        .paragraph("After tinnitus starts, it is a natural instinct to protect the ears everywhere. Clinicians consistently advise against wearing hearing protection in ordinary, non-hazardous environments, because sustained reduced input is associated with increased sensitivity to everyday sound and can make tinnitus more prominent rather than less."),
                        .paragraph("The line most people find workable: protect against genuinely loud exposure — concerts, tools, motorsport, shooting — and leave your ears open the rest of the time. If sound has become painful or intolerable at ordinary levels, that is worth raising with an audiologist, since it has its own management approaches.")
                    ], minutes: 2),

        NTLearnCard(id: "protect-headphones", groupID: "protect",
                    title: "Headphones and personal listening",
                    summary: "Where most avoidable exposure now comes from.",
                    blocks: [
                        .bullets([
                            "Noise-cancelling or well-sealing headphones let you listen at a lower level, because you are not raising the volume to beat the background.",
                            "Set the level in a quiet place, then leave it. Levels chosen on a train are usually far higher than intended.",
                            "Use whatever level limit or listening-time report your phone offers, and take it seriously.",
                            "Take a break of a few minutes each hour. Recovery time genuinely matters.",
                            "Never use this app's sounds at a level that competes with your tinnitus for prominence. That is the whole point of the output cap in Settings."
                        ]),
                        .callout("Sudden loud sound can make tinnitus worse, sometimes lastingly. Treat a single unprotected exposure as a real risk rather than one bad evening.")
                    ], minutes: 2),

        // MARK: Relax
        NTLearnCard(id: "relax-breath", groupID: "relax",
                    title: "A longer out-breath",
                    summary: "The simplest exercise, and the one most likely to be used.",
                    blocks: [
                        .paragraph("Making the exhale longer than the inhale reliably shifts the body toward a calmer state. It is not a cure for anything; it is a way of interrupting the alarm response that a loud night can set off."),
                        .bullets([
                            "Breathe in through the nose for a count of four.",
                            "Breathe out, slowly, through slightly pursed lips, for a count of six to eight.",
                            "Let the next in-breath arrive on its own rather than pulling it in.",
                            "Continue for two minutes. Two minutes done is better than ten minutes intended."
                        ]),
                        .paragraph("If counting makes you tense, drop the counting and simply make each out-breath a little longer than the one before until it settles.")
                    ], minutes: 2),

        NTLearnCard(id: "relax-progressive", groupID: "relax",
                    title: "Releasing tension from the top down",
                    summary: "Ten minutes, lying down, no equipment.",
                    blocks: [
                        .paragraph("Tension in the jaw, neck and shoulders is extremely common in people with tinnitus, and in many people it measurably changes the sound. Working through the body deliberately gives that tension somewhere to go."),
                        .bullets([
                            "Lie down. Bring attention to the forehead: tense gently for five seconds, then release and notice the difference for ten.",
                            "Move to the jaw. Let the teeth part slightly and the tongue rest away from the roof of the mouth.",
                            "Shoulders: lift toward the ears, hold, then let them drop completely.",
                            "Continue down through arms, hands, stomach, legs and feet.",
                            "Finish by lying still for a minute without doing anything at all."
                        ]),
                        .paragraph("If your tinnitus changes when you clench your jaw or press on your neck, mention that to your audiologist or dentist — it is a recognised pattern and there are people who work on it.")
                    ], minutes: 3),

        NTLearnCard(id: "relax-attention", groupID: "relax",
                    title: "Widening attention instead of fighting",
                    summary: "An exercise for a bad hour.",
                    blocks: [
                        .paragraph("Trying to not hear something focuses attention on it. A more workable move is to widen the field rather than narrow it: let the tinnitus be one item among many rather than the only item."),
                        .bullets([
                            "Name three sounds in the room other than the tinnitus, quietly and without judgement.",
                            "Add the feeling of your feet on the floor and your back against the chair.",
                            "Let the tinnitus be present in that field. You are not trying to remove it — you are declining to give it the whole stage.",
                            "Stay for a minute or two, then go back to what you were doing."
                        ]),
                        .paragraph("Done occasionally this changes little. Done regularly over weeks, most people find the sound occupies a smaller share of their attention, which is exactly what habituation looks like from the inside.")
                    ], minutes: 2),

        // MARK: Clinic
        NTLearnCard(id: "clinic-visit", groupID: "clinic",
                    title: "What an appointment involves",
                    summary: "The usual sequence, so nothing is a surprise.",
                    blocks: [
                        .paragraph("A first tinnitus appointment is mostly conversation and measurement. A typical sequence:"),
                        .bullets([
                            "History. When it started, which ear, what it sounds like, what makes it better or worse, noise exposure, medications, other symptoms.",
                            "Examination of the ear canal and eardrum, usually with an otoscope.",
                            "Pure-tone audiometry: the proper hearing test, in a sound-treated booth with calibrated equipment, mapping the quietest tone you can hear at each frequency in each ear.",
                            "Tympanometry, which checks how the eardrum and middle ear respond to pressure.",
                            "Speech testing in some clinics, to see how well you understand words rather than tones.",
                            "Tinnitus-specific measures, which may include a clinical pitch match, a loudness match and a minimum masking level — the calibrated versions of the exercises in this app.",
                            "A discussion of what was found and what options exist."
                        ]),
                        .callout("The pitch and loudness exercises in Notch Tone are self-matching on uncalibrated consumer hardware. They are not audiometry and cannot replace any part of the above.")
                    ], minutes: 4),

        NTLearnCard(id: "clinic-prepare", groupID: "clinic",
                    title: "Preparing for the appointment",
                    summary: "What to bring, and what to write down first.",
                    blocks: [
                        .bullets([
                            "A date for when it started, as precise as you can manage, and whether onset was sudden or gradual.",
                            "Which ear, or both, and whether that has changed.",
                            "A short description of the sound in your own words.",
                            "A list of medications and supplements, including doses and recent changes.",
                            "Your noise exposure history — jobs, hobbies, military service, concerts.",
                            "What you have already tried, and what happened.",
                            "Your two or three most important questions, written down. Appointments are short and it is easy to leave without asking them."
                        ]),
                        .paragraph("If you have been keeping the diary and self-check in this app, the trends are genuinely useful to show — not as a clinical score, but as an honest record of how your days have actually gone.")
                    ], minutes: 2),

        NTLearnCard(id: "clinic-questions", groupID: "clinic",
                    title: "Questions worth asking",
                    summary: "Concrete things to leave with.",
                    blocks: [
                        .bullets([
                            "Does my hearing test show any loss, and if so where and how much?",
                            "Is there anything in my history that needs further investigation or imaging?",
                            "Would amplification be likely to help, given my results?",
                            "What structured support is available here — counselling, a tinnitus management programme, a psychologist?",
                            "Is there anything about my medications worth reviewing?",
                            "What should make me come back sooner than planned?"
                        ]),
                        .paragraph("If you are told there is nothing to be done, it is reasonable to ask specifically about management and support rather than cure. Those are different questions and they usually have different answers.")
                    ], minutes: 2),

        // MARK: Devices
        NTLearnCard(id: "devices-aids", groupID: "devices",
                    title: "Why hearing aids come up so often",
                    summary: "Restoring input can reduce prominence.",
                    blocks: [
                        .paragraph("For people whose tinnitus accompanies hearing loss, hearing aids are among the most frequently recommended options. The reasoning is straightforward: amplification restores some of the input that was reduced, and it raises the level of ordinary environmental sound, which reduces the contrast that makes an internal sound stand out."),
                        .paragraph("Reported outcomes vary and the research base is not as strong as the frequency of the recommendation might suggest, but the intervention has the advantage of also addressing the hearing loss itself, which is worth doing regardless."),
                        .callout("Whether amplification is appropriate depends on an audiogram measured with calibrated equipment. Nothing this app measures can answer that question.")
                    ], minutes: 2),

        NTLearnCard(id: "devices-combination", groupID: "devices",
                    title: "Combination devices",
                    summary: "A hearing aid with a sound generator built in.",
                    blocks: [
                        .paragraph("A combination device is a hearing aid that also produces its own sound — noise, shaped noise, or in some models a set of gentle tonal patterns — which can be adjusted independently of the amplification. For someone who wants both amplification and a sound bed through the day, it removes the need to carry two things."),
                        .paragraph("Some models can be fitted with a notch or with shaped output related to a measured tinnitus pitch. If that interests you, ask about it directly; availability differs a great deal between manufacturers and clinics.")
                    ], minutes: 2),

        NTLearnCard(id: "devices-standalone", groupID: "devices",
                    title: "Standalone sound generators and apps",
                    summary: "Where a phone fits, and where it does not.",
                    blocks: [
                        .paragraph("Dedicated bedside sound generators, wearable generators and apps like this one all occupy the same niche: producing controllable sound without a clinical fitting. The advantages are cost, availability and the freedom to experiment. The limitation is calibration — a phone and an arbitrary pair of headphones have no known output level, so no number a phone produces is comparable to a clinical measurement."),
                        .paragraph("That limitation is why every number Notch Tone shows is described as a relative in-app value, and why the output is capped conservatively. Use the app for what it is good at: consistent, adjustable, code-generated sound and an honest record of your own days.")
                    ], minutes: 2),

        // MARK: Myths
        NTLearnCard(id: "myth-nothing", groupID: "myths",
                    title: "\"Nothing can be done\"",
                    summary: "Widely said, and wrong in an important way.",
                    blocks: [
                        .paragraph("It is true that for most people there is no intervention that removes the sound. It does not follow that nothing can be done, and the two get conflated constantly."),
                        .paragraph("What can change — often substantially — is how much of your life the sound takes. Structured counselling approaches, cognitive behavioural therapy, sound approaches, sleep work, and addressing hearing loss all have a record of improving how people function, even with the sound unchanged. Hearing \"nothing can be done\" as \"no help exists\" is one of the more damaging misunderstandings in this field.")
                    ], minutes: 2),

        NTLearnCard(id: "myth-deaf", groupID: "myths",
                    title: "\"It means I am going deaf\"",
                    summary: "Associated, but not a prediction.",
                    blocks: [
                        .paragraph("Tinnitus is associated with hearing loss, and many people with tinnitus have some measurable loss, sometimes in frequency regions that ordinary testing does not reach. But tinnitus is not a forecast of progressive deafness, and plenty of people with clinically normal hearing have it."),
                        .paragraph("The sensible response is not worry but measurement: get an audiogram from an audiologist so you know where you actually stand, and repeat it if anything changes.")
                    ], minutes: 2),

        NTLearnCard(id: "myth-supplements", groupID: "myths",
                    title: "\"This supplement cures it\"",
                    summary: "A crowded market with very little behind it.",
                    blocks: [
                        .paragraph("Tinnitus attracts an enormous number of products promising resolution. Reviews of the commonly marketed supplements have generally not found convincing evidence that any of them reduce tinnitus, and some interact with medications."),
                        .callout("Notch Tone does not recommend or discourage any specific product, and cannot advise on anything you take. Discuss supplements with a pharmacist or doctor, particularly if you take other medication."),
                        .paragraph("A useful filter: be sceptical of anything that promises to remove the sound, cites only testimonials, or is sold with a countdown timer.")
                    ], minutes: 2),

        NTLearnCard(id: "myth-loud", groupID: "myths",
                    title: "\"Louder masking works better\"",
                    summary: "The opposite is usually true.",
                    blocks: [
                        .paragraph("It is intuitive that if a little sound helps, more will help more. In practice higher levels bring three problems: they carry their own risk to hearing, they make the return to quiet more jarring, and they remove the partial audibility that most structured approaches deliberately preserve."),
                        .paragraph("Almost everyone who uses sound successfully over months settles on a level far lower than the one they started with. Starting low is not caution for its own sake — it is where you are likely to end up anyway.")
                    ], minutes: 2),

        // MARK: Evidence
        NTLearnCard(id: "evidence-strong", groupID: "evidence",
                    title: "Where the evidence is strongest",
                    summary: "Psychological approaches lead, by some distance.",
                    blocks: [
                        .paragraph("Across systematic reviews, the approach with the most consistent support for reducing tinnitus-related distress is cognitive behavioural therapy and closely related structured psychological approaches. Notably, these generally do not change loudness ratings much — what they change is the impact on daily life, which is the outcome that matters most to people living with it."),
                        .paragraph("Addressing hearing loss where it exists is also widely supported, both for its own sake and for the reduced contrast that amplification provides.")
                    ], minutes: 2),

        NTLearnCard(id: "evidence-mixed", groupID: "evidence",
                    title: "Where the evidence is mixed",
                    summary: "Sound approaches, including the one this app generates.",
                    blocks: [
                        .paragraph("Sound-based approaches, including notched sound, notched music and various forms of masking, sit in a more uncertain place. Individual studies report benefit; reviews tend to conclude that the trials are small, methods differ too much to pool cleanly, and blinding is difficult because participants can hear which condition they are in."),
                        .paragraph("That is not a reason to dismiss them — many people find them genuinely useful, they are low-risk when used at sensible levels, and they are inexpensive. It is a reason to keep expectations proportionate and to judge by your own record over weeks rather than by a good evening."),
                        .callout("Notch Tone exists to give you a well-engineered, precisely controllable version of this to try. It does not claim the question is settled.")
                    ], minutes: 3),

        NTLearnCard(id: "evidence-judge", groupID: "evidence",
                    title: "Judging something for yourself",
                    summary: "How to run a fair personal trial.",
                    blocks: [
                        .paragraph("Personal experiments are worth doing, but day-to-day fluctuation will fool you unless you set them up carefully."),
                        .bullets([
                            "Change one thing at a time, and give it at least four weeks.",
                            "Rate at the same time each day, not when the sound is at its worst.",
                            "Use the same metric throughout. The Diary tab keeps loudness, annoyance and sleep separate for exactly this reason.",
                            "Compare a window against the window before it rather than against your memory, which is unreliable and biased toward bad days.",
                            "Expect a small effect. Anything dramatic is more likely to be a good fortnight than a discovery."
                        ]),
                        .paragraph("The correlation view in the Diary tab is built on this principle: it shows means and sample counts side by side, refuses to print a number under five samples, and never calls an association a cause.")
                    ], minutes: 3)
    ]

    // MARK: - Exposure reference

    struct NTExposureRow: Identifiable {
        let id: String
        let source: String
        let level: String
        let safeTime: String
        let severity: Int  // 0 quiet, 1 moderate, 2 loud, 3 hazardous
    }

    /// Commonly cited approximate levels and exposure durations, for orientation only.
    static let exposureRows: [NTExposureRow] = [
        NTExposureRow(id: "e0", source: "Quiet bedroom at night", level: "30 dB", safeTime: "No limit", severity: 0),
        NTExposureRow(id: "e1", source: "Library, soft conversation", level: "45 dB", safeTime: "No limit", severity: 0),
        NTExposureRow(id: "e2", source: "Normal conversation", level: "60 dB", safeTime: "No limit", severity: 0),
        NTExposureRow(id: "e3", source: "Busy street, vacuum cleaner", level: "75 dB", safeTime: "No practical limit", severity: 1),
        NTExposureRow(id: "e4", source: "Heavy traffic, hair dryer", level: "85 dB", safeTime: "About 8 hours", severity: 1),
        NTExposureRow(id: "e5", source: "Underground train, blender", level: "94 dB", safeTime: "About 1 hour", severity: 2),
        NTExposureRow(id: "e6", source: "Motorcycle, lawn mower", level: "97 dB", safeTime: "About 30 minutes", severity: 2),
        NTExposureRow(id: "e7", source: "Nightclub, loud concert", level: "103 dB", safeTime: "About 7 minutes", severity: 3),
        NTExposureRow(id: "e8", source: "Chainsaw, front of a speaker stack", level: "110 dB", safeTime: "Under 2 minutes", severity: 3),
        NTExposureRow(id: "e9", source: "Siren at close range", level: "120 dB", safeTime: "Seconds", severity: 3),
        NTExposureRow(id: "e10", source: "Firework at close range, gunshot", level: "140 dB", safeTime: "Immediate risk", severity: 3)
    ]

    static func severityColor(_ s: Int) -> Color {
        switch s {
        case 0: return NTTheme.seriesMask
        case 1: return NTTheme.cyan
        case 2: return NTTheme.seriesScore
        default: return NTTheme.amber
        }
    }
}
