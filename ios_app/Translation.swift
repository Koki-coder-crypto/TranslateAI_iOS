import Foundation

struct Translation: Identifiable, Codable {
    var id = UUID()
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let translatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, originalText, translatedText, sourceLanguage, targetLanguage, translatedAt
    }
}

class TranslationStore: ObservableObject {
    @Published var translations: [Translation] = []
    private let saveKey = "translations_v1"

    init() { load() }

    func add(_ t: Translation) {
        translations.insert(t, at: 0)
        if translations.count > 100 { translations = Array(translations.prefix(100)) }
        save()
    }

    func delete(at offsets: IndexSet) { translations.remove(atOffsets: offsets); save() }

    private func save() { if let d = try? JSONEncoder().encode(translations) { UserDefaults.standard.set(d, forKey: saveKey) } }
    private func load() { if let d = UserDefaults.standard.data(forKey: saveKey), let v = try? JSONDecoder().decode([Translation].self, from: d) { translations = v } }
}

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let flag: String
}

extension Language {
    static let all: [Language] = [
        Language(id: "auto",  name: "Auto Detect", flag: "🔍"),
        Language(id: "ja",    name: "Japanese",    flag: "🇯🇵"),
        Language(id: "en",    name: "English",     flag: "🇺🇸"),
        Language(id: "zh",    name: "Chinese",     flag: "🇨🇳"),
        Language(id: "ko",    name: "Korean",      flag: "🇰🇷"),
        Language(id: "es",    name: "Spanish",     flag: "🇪🇸"),
        Language(id: "fr",    name: "French",      flag: "🇫🇷"),
        Language(id: "de",    name: "German",      flag: "🇩🇪"),
        Language(id: "pt",    name: "Portuguese",  flag: "🇧🇷"),
        Language(id: "it",    name: "Italian",     flag: "🇮🇹"),
        Language(id: "ar",    name: "Arabic",      flag: "🇸🇦"),
        Language(id: "hi",    name: "Hindi",       flag: "🇮🇳"),
        Language(id: "ru",    name: "Russian",     flag: "🇷🇺"),
    ]

    static var defaultTarget: Language { all.first { $0.id == "ja" }! }
    static var autoDetect: Language { all.first { $0.id == "auto" }! }
}
